# 1. The VPC 
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16" # Provides 65,536 IP addresses
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "EV-Fleet-VPC"
  }
}

# 2. The Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "EV-Fleet-IGW"
  }
}

# 3. Two Public Subnets (Spread across Sydney AZs 'a' and 'b' for High Availability)
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-southeast-2a"
  map_public_ip_on_launch = true # Automatically gives containers a public IP

  tags = {
    Name = "EV-Fleet-Public-Subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-southeast-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "EV-Fleet-Public-Subnet-2"
  }
}

# 4. Route Table 
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Link both subnets to the Route Table
resource "aws_route_table_association" "public_rta_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rta_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# 5. Security Groups (The Firewalls)

# ALB Firewall: Open to the world on ports 80 (HTTP) and 443 (HTTPS)
resource "aws_security_group" "alb_sg" {
  name        = "EV-Fleet-ALB-SG"
  description = "Allow web traffic from anywhere"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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

# ECS Container Firewall: NESTED SECURITY! Only accepts traffic if it comes from the ALB
resource "aws_security_group" "ecs_sg" {
  name        = "EV-Fleet-ECS-SG"
  description = "Allow traffic only from the Application Load Balancer"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1" # Allow all ports/protocols...
    security_groups = [aws_security_group.alb_sg.id] # ...BUT ONLY from the ALB firewall
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 6. Two Application Load Balancers (One for each microservice)
resource "aws_lb" "alb_telemetry" {
  name               = "EV-Fleet-Telemetry-ALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}

resource "aws_lb" "alb_management" {
  name               = "EV-Fleet-Management-ALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}