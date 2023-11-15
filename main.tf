resource "aws_vpc" "vpc_demo" {
    cidr_block = var.vpc_cidr_block
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

resource "aws_subnet" "mysubnet" {
  count                   = length(var.subnet_cidr_blocks)
  vpc_id                  = aws_vpc.vpc_demo.id
  cidr_block              = var.subnet_cidr_blocks[count.index]
  availability_zone       = element(["ap-south-1a", "ap-south-1b"], count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "Subnet-${count.index + 1}"
  }
}

resource "aws_route_table_association" "RTassoc" {
  count             = 2
  subnet_id         = aws_subnet.mysubnet[count.index].id
  route_table_id    = aws_route_table.pubRT.id
}

resource "aws_internet_gateway" "igw" {
   vpc_id = aws_vpc.vpc_demo.id
   tags = {
       Name = "my_igw"
   }
}

resource "aws_security_group" "alb_sg" {
  name        = "app-sg"
  description = "Security group for ALB"
  vpc_id = aws_vpc.vpc_demo.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_sg" {
  name        = "inst-sg"
  description = "Security group for ALB"
  vpc_id = aws_vpc.vpc_demo.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "alb_to_ec2" {
  security_group_id        = aws_security_group.ec2_sg.id
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
}

resource "aws_lb_target_group" "my_TG" {
  name     = "my-TG-demo"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc_demo.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    port                = 80
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }
}

resource "aws_instance" "pub_ec2" {
  
  count         = 2
  ami           = var.ami
  instance_type = var.inst_type
  availability_zone = element(["ap-south-1a", "ap-south-1b"], count.index)
  key_name = "kv-key"
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id = aws_subnet.mysubnet[count.index].id

  user_data = <<-EOF
  #!/bin/bash
  yum update -y
  yum install httpd -y
  systemctl start httpd
  systemctl enable httpd
  echo "<h1> Hello World from $(hostname -f) </h1>" > /var/www/html/index.html
  EOF

  tags = {
    Name        = "Instance-${count.index + 1}"
  }
}

resource "aws_lb" "my_alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.mysubnet[0].id, aws_subnet.mysubnet[1].id]  # Specify the subnets where the ALB should be deployed
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_TG.arn
  }
}

resource "aws_lb_target_group_attachment" "ec2_targets" {
  count          = length(aws_instance.pub_ec2)
  target_group_arn = aws_lb_target_group.my_TG.arn
  target_id        = element(aws_instance.pub_ec2[*].id,count.index)
}
