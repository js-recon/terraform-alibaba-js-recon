provider "alicloud" {
  region = "ap-southeast-1"
}

module "js_recon" {
  source = "../../"

  url      = "https://example.com"
  region   = "ap-southeast-1"
  schedule = "0 8 * * *"

  break_on_map_files       = true
  break_on_vulnerabilities = true
  vulnerability_severity   = "high"

  tags = {
    team = "security"
  }
}

output "container_group_name" {
  value = module.js_recon.container_group_name
}

output "oss_bucket_name" {
  value = module.js_recon.oss_bucket_name
}
