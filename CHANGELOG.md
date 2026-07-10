# Changelog

## 1.0.1 — Unreleased

## 1.0.0 — 2026-07-10

Initial release.

- Alibaba Cloud ECI container group running JS Recon against any URL using the Puppeteer Docker image
- VPC, VSwitch, and security group provisioned by the module
- RAM role with OSS write policy for artifact upload via ECS RAM Role auth
- Optional OSS bucket for artifact storage
- Inputs mirroring the GitHub Action and GitLab CI component: `url`, `js_recon_version`, `break_on_map_files`, `break_on_vulnerabilities`, `vulnerability_severity`, `output_dir`
- Outputs: `container_group_name`, `container_group_id`, `oss_bucket_name`, `ram_role_name`, `vpc_id`, `vswitch_id`
- Examples: `basic/` (on-demand) and `scheduled/` (documents EventBridge scheduling via console)
