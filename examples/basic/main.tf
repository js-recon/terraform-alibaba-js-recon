provider "alicloud" {
  region = "ap-southeast-1"
  # access_key = var.access_key  # set via ALICLOUD_ACCESS_KEY env var
  # secret_key = var.secret_key  # set via ALICLOUD_SECRET_KEY env var
}

module "js_recon" {
  source = "../../"

  url    = "https://example.com"
  region = "ap-southeast-1"
}

output "container_group_name" {
  value = module.js_recon.container_group_name
}

output "oss_bucket_name" {
  value = module.js_recon.oss_bucket_name
}
