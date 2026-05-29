variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "my_ip" {
  description = "Your public IP in CIDR notation (e.g. 1.2.3.4/32) allowed for SSH"
  type        = string
}

variable "public_key_file" {
  description = "SSH public key file (in the terraform/ folder) uploaded to the EC2 key pair"
  type        = string
  default     = "deployer.pub"
}

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
  default     = "jenkins-agent"
}
