variable "vpc_cidr_block" {
  description = "CIDR block for VPC"
  default     = "12.0.0.0/16"
}

variable "subnet_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks for subnets"
  default     = ["12.0.1.0/24", "12.0.2.0/24"]
}

variable "aws_region" {
        description = "this will define the region"
        type = string
        default = "ap-south-1"
}

variable "inst_type" {
	type =string
	default = "t2.micro"
}

variable "ami" {
	type = string
	default = "ami-02e94b011299ef128"
}
