locals {
  oss_bucket_name = var.oss_bucket_name != "" ? var.oss_bucket_name : "${var.name_prefix}-${random_id.oss_suffix[0].hex}"
}

resource "random_id" "oss_suffix" {
  count       = var.create_oss_bucket && var.oss_bucket_name == "" ? 1 : 0
  byte_length = 4
}

# ─── VPC and VSwitch ──────────────────────────────────────────────────────────

resource "alicloud_vpc" "js_recon" {
  vpc_name   = "${var.name_prefix}-vpc"
  cidr_block = "10.0.0.0/16"
  tags       = var.tags
}

resource "alicloud_vswitch" "js_recon" {
  vpc_id       = alicloud_vpc.js_recon.id
  cidr_block   = "10.0.0.0/24"
  zone_id      = data.alicloud_zones.available.zones[0].id
  vswitch_name = "${var.name_prefix}-vswitch"
  tags         = var.tags
}

data "alicloud_zones" "available" {
  available_resource_creation = "VSwitch"
}

# ─── Security group ───────────────────────────────────────────────────────────

resource "alicloud_security_group" "js_recon" {
  security_group_name = "${var.name_prefix}-sg"
  description         = "Security group for JS Recon ECI container group"
  vpc_id              = alicloud_vpc.js_recon.id
  tags                = var.tags
}

resource "alicloud_security_group_rule" "egress_all" {
  type              = "egress"
  ip_protocol       = "all"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "-1/-1"
  priority          = 1
  security_group_id = alicloud_security_group.js_recon.id
  cidr_ip           = "0.0.0.0/0"
}

# ─── RAM role for OSS access ──────────────────────────────────────────────────

resource "alicloud_ram_role" "js_recon" {
  role_name                   = "${var.name_prefix}-eci-role"
  assume_role_policy_document = <<-POLICY
    {
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Effect": "Allow",
          "Principal": {
            "Service": ["eci.aliyuncs.com"]
          }
        }
      ],
      "Version": "1"
    }
  POLICY
  description                 = "RAM role for JS Recon ECI to write artifacts to OSS"
  force                       = true
}

resource "alicloud_ram_policy" "oss_write" {
  count       = var.create_oss_bucket ? 1 : 0
  policy_name = "${var.name_prefix}-oss-write"
  policy_document = jsonencode({
    Version = "1"
    Statement = [{
      Effect = "Allow"
      Action = ["oss:PutObject", "oss:GetObject", "oss:ListObjects"]
      Resource = [
        "acs:oss:*:*:${local.oss_bucket_name}",
        "acs:oss:*:*:${local.oss_bucket_name}/*"
      ]
    }]
  })
  description = "Allow JS Recon ECI to write artifacts to OSS bucket ${local.oss_bucket_name}"
  force       = true
}

resource "alicloud_ram_role_policy_attachment" "oss_write" {
  count       = var.create_oss_bucket ? 1 : 0
  role_name   = alicloud_ram_role.js_recon.role_name
  policy_name = alicloud_ram_policy.oss_write[0].policy_name
  policy_type = "Custom"
}

# ─── OSS bucket ───────────────────────────────────────────────────────────────

resource "alicloud_oss_bucket" "artifacts" {
  count  = var.create_oss_bucket ? 1 : 0
  bucket = local.oss_bucket_name
  tags   = var.tags
}

resource "alicloud_oss_bucket_acl" "artifacts" {
  count  = var.create_oss_bucket ? 1 : 0
  bucket = alicloud_oss_bucket.artifacts[0].bucket
  acl    = "private"
}

# ─── ECI container group ──────────────────────────────────────────────────────

resource "alicloud_eci_container_group" "js_recon" {
  container_group_name = var.name_prefix
  vswitch_id           = alicloud_vswitch.js_recon.id
  security_group_id    = alicloud_security_group.js_recon.id
  ram_role_name        = alicloud_ram_role.js_recon.role_name
  cpu                  = var.container_cpu
  memory               = var.container_memory_gb
  tags                 = var.tags

  restart_policy = "Never"

  containers {
    name   = "js-recon"
    image  = "ghcr.io/puppeteer/puppeteer:24.43.1"
    cpu    = var.container_cpu
    memory = var.container_memory_gb

    commands = ["/bin/bash", "-c", <<-SCRIPT
      set -e
      npm config set prefix /home/pptruser/.npm-global
      export PATH="/home/pptruser/.npm-global/bin:$PATH"

      echo "[js-recon] Installing @shriyanss/js-recon@$JSR_VERSION..."
      npm install -g "@shriyanss/js-recon@$JSR_VERSION"
      INSTALLED_VERSION=$(js-recon --version 2>/dev/null || echo "unknown")
      echo "[js-recon] Installed version: $INSTALLED_VERSION"

      echo "[js-recon] Running js-recon against $JSR_URL..."
      js-recon run -u "$JSR_URL" -o "$JSR_OUTPUT_DIR" --no-sandbox -y -k || {
        echo "[js-recon] ERROR: js-recon run failed."
        exit 1
      }
      echo "[js-recon] Scan complete."

      HOST_DIR=$(echo "$JSR_URL" | sed 's|https\?://||' | sed 's|[/?].*||' | tr ':' '_')
      mkdir -p "$JSR_OUTPUT_DIR/$HOST_DIR"
      for f in analyze.json mapped.json mapped-openapi.json endpoints.json strings.json report.html report.db js-recon.db; do
        [ -f "$f" ] && mv "$f" "$JSR_OUTPUT_DIR/$HOST_DIR/" 2>/dev/null || true
      done

      MAP_FILES=$(find "$JSR_OUTPUT_DIR" -name "*.map" 2>/dev/null | head -50)
      if [ -n "$MAP_FILES" ]; then
        echo "[js-recon] Source map files detected:"
        echo "$MAP_FILES"
        if [ "$JSR_BREAK_ON_MAP" = "true" ]; then
          echo "[js-recon] ERROR: Source map files are publicly accessible. Set break_on_map_files = false to suppress."
          exit 1
        fi
      fi

      ANALYZE_JSON=$(find "$JSR_OUTPUT_DIR" -name "analyze.json" 2>/dev/null | head -1)
      if [ -n "$ANALYZE_JSON" ] && [ "$JSR_BREAK_ON_VULNS" = "true" ]; then
        node -e "
      const fs = require('fs');
      const RANK = {info: 0, low: 1, medium: 2, high: 3};
      let findings = [];
      try { findings = JSON.parse(fs.readFileSync(process.argv[1], 'utf8')); } catch {
        console.log('[js-recon] analyze.json is empty or invalid. Skipping.');
        process.exit(0);
      }
      if (!Array.isArray(findings) || findings.length === 0) {
        console.log('[js-recon] No findings in analyze.json.');
        process.exit(0);
      }
      const severity = process.argv[2];
      const threshold = RANK[severity] ?? 3;
      const matched = findings.filter(f => (RANK[f.severity?.toLowerCase()] ?? -1) >= threshold);
      if (matched.length === 0) {
        console.log('[js-recon] No findings at or above severity \"' + severity + '\".');
        process.exit(0);
      }
      console.log('[js-recon] ' + matched.length + ' finding(s) at or above severity \"' + severity + '\":\n');
      console.log('Rule'.padEnd(40) + ' ' + 'Severity'.padEnd(10) + ' Location');
      console.log('-'.repeat(80));
      for (const f of matched) {
        const rule = (f.ruleName || f.ruleId || 'unknown').substring(0, 39).padEnd(40);
        const sev  = (f.severity || '?').padEnd(10);
        const loc  = f.findingLocation || '';
        console.log(rule + ' ' + sev + ' ' + loc);
      }
      console.log('\n[js-recon] ERROR: ' + matched.length + ' vulnerability/vulnerabilities at severity \"' + severity + '\" or above.');
      process.exit(matched.length > 255 ? 255 : matched.length);
        " "$ANALYZE_JSON" "$JSR_SEVERITY" || exit 1
      fi

      if [ -n "$JSR_OSS_BUCKET" ]; then
        echo "[js-recon] Uploading artifacts to Alibaba Cloud OSS..."
        curl -s https://gosspublic.alicdn.com/ossutil/install.sh | bash
        ossutil config -e "oss-$JSR_REGION.aliyuncs.com" \
          --mode EcsRamRole \
          --ecs-role-name "$JSR_RAM_ROLE" \
          -c /root/.ossutilconfig
        ossutil cp -r "$JSR_OUTPUT_DIR/" "oss://$JSR_OSS_BUCKET/$JSR_OSS_PREFIX/" \
          -c /root/.ossutilconfig
        echo "[js-recon] Artifacts uploaded to oss://$JSR_OSS_BUCKET/$JSR_OSS_PREFIX/"
      fi
    SCRIPT
    ]

    environment_vars {
      key   = "JSR_URL"
      value = var.url
    }
    environment_vars {
      key   = "JSR_VERSION"
      value = var.js_recon_version
    }
    environment_vars {
      key   = "JSR_BREAK_ON_MAP"
      value = tostring(var.break_on_map_files)
    }
    environment_vars {
      key   = "JSR_BREAK_ON_VULNS"
      value = tostring(var.break_on_vulnerabilities)
    }
    environment_vars {
      key   = "JSR_SEVERITY"
      value = var.vulnerability_severity
    }
    environment_vars {
      key   = "JSR_OUTPUT_DIR"
      value = var.output_dir
    }
    environment_vars {
      key   = "JSR_OSS_BUCKET"
      value = var.create_oss_bucket ? local.oss_bucket_name : ""
    }
    environment_vars {
      key   = "JSR_OSS_PREFIX"
      value = var.oss_artifact_prefix
    }
    environment_vars {
      key   = "JSR_REGION"
      value = var.region
    }
    environment_vars {
      key   = "JSR_RAM_ROLE"
      value = alicloud_ram_role.js_recon.role_name
    }
    environment_vars {
      key   = "PUPPETEER_SKIP_DOWNLOAD"
      value = "true"
    }
    environment_vars {
      key   = "IS_DOCKER"
      value = "true"
    }
    environment_vars {
      key   = "NODE_OPTIONS"
      value = "--max-http-header-size=99999999"
    }
    environment_vars {
      key   = "PUPPETEER_CACHE_DIR"
      value = "/home/pptruser/.cache/puppeteer"
    }
  }
}
