variable "vpc_cidr" {
  description = "CIDR block for main"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_name" {
  type = string
}

variable "sg_name" {
  type = string
}

variable "instance_name" {
  type = string
}

variable "subnet_name" {
  type = string
}

variable "igw_name" {
  type = string
}

variable "route_table_name" {
  type = string
}