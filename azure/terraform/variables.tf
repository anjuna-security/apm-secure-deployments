variable "instance_size" {
  description = "The size of the VM instance to create"
  default     = "Standard_DC4as_v5"
}

variable "location" {
  description = "The geo location where resources should be created at"
  default     = "east us"
}

variable "group_name" {
  description = "The name of the resource group to be created"
  default     = ""
}

variable "apm_hostname" {
  description = "The hostname of the APM server"
  default     = "apm-server.test"
}

variable "apm_port" {
  description = "The http port on which APM is listening"
  default     = "8200"
}

variable "base_address_prefix" {
  description = "The base address prefix for APM's virtual network"
  default     = "10.0"
}

variable "apm_image_version" {
  description = "APM image version to be used for the CVM instance"
  default     = "1.0.0"
}

variable "apm_master_key_name" {
  description = "Name of the APM master key to be created in the key vault"
  default     = "apm-master-key"
}

