<h1 align="center">JS Recon — Terraform Alibaba Cloud Module</h1>

<p align="center">
  Provision an Alibaba Cloud ECI container group that runs <a href="https://js-recon.io">JS Recon</a> against any URL.
  Surface exposed endpoints, client-side vulnerabilities, and leaked source maps automatically.
</p>

---

## Quick start

```hcl
module "js_recon" {
  source  = "js-recon/js-recon/alibaba"
  version = "~> 1.0"

  url    = "https://example.com"
  region = "ap-southeast-1"
}
```

Set credentials before applying:

```bash
export ALICLOUD_ACCESS_KEY="..."
export ALICLOUD_SECRET_KEY="..."
terraform apply
```

Restart the container group to run another scan:

```bash
aliyun eci RestartContainerGroup \
  --RegionId ap-southeast-1 \
  --ContainerGroupId <container_group_id>
```

---

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `url` | Yes | — | Target URL to scan |
| `region` | Yes | — | Alibaba Cloud region (e.g. `ap-southeast-1`, `cn-hangzhou`) |
| `js_recon_version` | No | `latest` | JS Recon version (`latest`, `alpha`, `1.3.1-beta.1`, …) |
| `break_on_map_files` | No | `true` | Fail if `.map` source map files are detected |
| `break_on_vulnerabilities` | No | `true` | Fail if findings at or above the threshold are detected |
| `vulnerability_severity` | No | `high` | Minimum severity: `low`, `medium`, or `high` |
| `output_dir` | No | `js-recon-output` | Directory to save output files inside the container |
| `name_prefix` | No | `js-recon` | Name prefix for all Alibaba Cloud resources |
| `container_cpu` | No | `2` | CPU units for the ECI container group |
| `container_memory_gb` | No | `4` | Memory in GB for the ECI container group |
| `create_oss_bucket` | No | `true` | Whether the module creates an OSS bucket for artifacts |
| `oss_bucket_name` | No | _(auto-generated)_ | OSS bucket name (must be globally unique) |
| `oss_artifact_prefix` | No | `js-recon-output` | OSS object key prefix for uploaded artifacts |
| `schedule` | No | `""` | Cron expression for reference; see Scheduled Scans below |
| `build_timeout` | No | `1800` | Maximum scan duration in seconds |
| `tags` | No | `{}` | Tags applied to all Alibaba Cloud resources |

## Outputs

| Name | Description |
|---|---|
| `container_group_name` | Name of the ECI container group |
| `container_group_id` | ID of the ECI container group |
| `oss_bucket_name` | Name of the OSS bucket |
| `ram_role_name` | Name of the RAM role assigned to the container group |
| `vpc_id` | ID of the VPC |
| `vswitch_id` | ID of the VSwitch |

---

## Output files

JS Recon writes the following files and uploads them to OSS using `ossutil` with ECS RAM Role authentication:

| File | Description |
|---|---|
| `analyze.json` | All vulnerability findings |
| `mapped.json` | Parsed bundle structure |
| `mapped-openapi.json` | Extracted HTTP endpoints (OpenAPI format) |
| `endpoints.json` | Client-side routes |
| `strings.json` | Extracted strings, URLs, and secrets |
| `report.html` | Full HTML report |
| `js-recon.db` | SQLite database of all findings |

---

## Break conditions

### Source maps

```hcl
module "js_recon" {
  source = "js-recon/js-recon/alibaba"
  url    = "https://example.com"
  region = "ap-southeast-1"

  break_on_map_files = true # default
}
```

### Vulnerabilities

```hcl
module "js_recon" {
  source = "js-recon/js-recon/alibaba"
  url    = "https://example.com"
  region = "ap-southeast-1"

  break_on_vulnerabilities = true
  vulnerability_severity   = "medium"
}
```

---

## Scheduled scans

EventBridge scheduled event source is not yet fully supported via Terraform. To set up a recurring scan, create an EventBridge scheduled rule via the Alibaba Cloud console:

1. Go to **EventBridge → Event Sources → Create Event Source**
2. Select **Scheduled Event** and enter the cron expression (e.g. `0 8 * * *`)
3. Create an EventBridge rule targeting the ECI container group restart API

---

## Examples

- [`examples/basic/`](examples/basic/) — minimal on-demand scan
- [`examples/scheduled/`](examples/scheduled/) — includes schedule variable documentation

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

---

## License

MIT — see [LICENSE](LICENSE).
