variable "url" {
  description = "Target URL to scan (e.g. https://example.com or http://localhost:3000)"
  type        = string
}

variable "js_recon_version" {
  description = "JS Recon version to install — passed to npm install -g @js-recon/js-recon@<version> (e.g. latest, alpha, 1.3.1-beta.1)"
  type        = string
  default     = "latest"
}

variable "break_on_map_files" {
  description = "Fail the job if .map source map files are detected in the output"
  type        = bool
  default     = true
}

variable "break_on_vulnerabilities" {
  description = "Fail the job if vulnerabilities at or above the configured severity are detected"
  type        = bool
  default     = true
}

variable "vulnerability_severity" {
  description = "Minimum severity to fail on: low, medium, or high"
  type        = string
  default     = "high"

  validation {
    condition     = contains(["low", "medium", "high"], var.vulnerability_severity)
    error_message = "vulnerability_severity must be one of: low, medium, high"
  }
}

variable "output_dir" {
  description = "Directory inside the container where JS Recon output files are saved"
  type        = string
  default     = "js-recon-output"
}

variable "name_prefix" {
  description = "Name prefix for all Alibaba Cloud resources created by this module"
  type        = string
  default     = "js-recon"
}

variable "region" {
  description = "Alibaba Cloud region ID (e.g. cn-hangzhou, ap-southeast-1, us-east-1)"
  type        = string
  default     = "ap-southeast-1"
}

variable "container_cpu" {
  description = "CPU units allocated to the ECI container group (e.g. 2.0)"
  type        = number
  default     = 2
}

variable "container_memory_gb" {
  description = "Memory in GB allocated to the ECI container group"
  type        = number
  default     = 4
}

variable "create_oss_bucket" {
  description = "Whether to create an OSS bucket for storing JS Recon output artifacts"
  type        = bool
  default     = true
}

variable "oss_bucket_name" {
  description = "Name of the OSS bucket. Must be globally unique. Auto-generated if empty."
  type        = string
  default     = ""
}

variable "oss_artifact_prefix" {
  description = "OSS object key prefix for uploaded artifacts"
  type        = string
  default     = "js-recon-output"
}

variable "schedule" {
  description = "Cron expression for automated scans via Alibaba EventBridge (e.g. 0 8 * * *). Leave empty to disable."
  type        = string
  default     = ""
}

variable "build_timeout" {
  description = "Maximum duration in seconds for a single ECI run"
  type        = number
  default     = 1800
}

variable "tags" {
  description = "Tags to apply to all Alibaba Cloud resources created by this module"
  type        = map(string)
  default     = {}
}
