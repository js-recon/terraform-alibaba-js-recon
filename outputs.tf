output "container_group_name" {
  description = "Name of the ECI container group"
  value       = alicloud_eci_container_group.js_recon.container_group_name
}

output "container_group_id" {
  description = "ID of the ECI container group"
  value       = alicloud_eci_container_group.js_recon.id
}

output "oss_bucket_name" {
  description = "Name of the OSS bucket where JS Recon artifacts are stored"
  value       = var.create_oss_bucket ? alicloud_oss_bucket.artifacts[0].bucket : var.oss_bucket_name
}

output "ram_role_name" {
  description = "Name of the RAM role assigned to the ECI container group"
  value       = alicloud_ram_role.js_recon.role_name
}

output "vpc_id" {
  description = "ID of the VPC created for the ECI container group"
  value       = alicloud_vpc.js_recon.id
}

output "vswitch_id" {
  description = "ID of the VSwitch created for the ECI container group"
  value       = alicloud_vswitch.js_recon.id
}
