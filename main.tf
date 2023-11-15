resource "aws_vpc" "vpc_demo" {
    cidr_block = 
    enable_dns_support = "true" #gives you an internal domain name
    enable_dns_hostnames = "true" #gives you an internal host name
    instance_tenancy = "default"
    tags = {
        Name = "my-vpc"
    }
}

resource "aws_route_table" "pubRT" {
  vpc_id = aws_vpc.vpc_demo.id
  route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
       Name = "public-routetable"
  }
}
