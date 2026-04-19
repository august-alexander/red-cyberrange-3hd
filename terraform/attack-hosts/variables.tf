variable "region" {
  type    = string
  default = "us-east-1"
}

variable "attack_hosts" {
  description = "Map of attack hosts to create. Key becomes the Name tag. Leave object empty ({}) to use defaults."
  type = map(object({
    instance_type = optional(string)
    ami_id        = optional(string)
    subnet_id     = optional(string)
  }))
  default = {
    ClientAttackHost = {}
  }
}

variable "default_ami_id" {
  description = "Ubuntu 24.04 Noble amd64 in us-east-1. Temporary — swap to Kali AMI later."
  type        = string
  default     = "ami-0ec10929233384c7f"
}

variable "default_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "default_subnet_id" {
  type    = string
  default = "subnet-0a0fb941020f9e378"
}

variable "security_group_ids" {
  description = "SGs attached to every attack host. Managed in another TF config (cyberrange-saas)."
  type        = list(string)
  default     = ["sg-0a63d1aba8e2d0764"]
}

variable "key_name" {
  type    = string
  default = "admincontrol"
}

variable "root_volume_size_gb" {
  type    = number
  default = 20
}
