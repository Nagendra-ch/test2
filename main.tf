
provider "aws" {
  profile = "default"
  region  = "us-east-1"
}
resource "aws_key_pair" "redhat" {
  key_name   = "redhat"
  public_key = file("~/.ssh/id_rsa.pub")
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Main  vpc
resource "aws_vpc" "main" {
  cidr_block           = var.VPC_CIDR_BLOCK
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  tags = {
    Name = "${var.PROJECT_NAME}-vpc"
  }
}

# Public subnets

#public Subnet 1
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.VPC_PUBLIC_SUBNET1_CIDR_BLOCK
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = "true"
  tags = {
    Name = "${var.PROJECT_NAME}-vpc-public-subnet-1"
  }
}
#public Subnet 2
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.VPC_PUBLIC_SUBNET2_CIDR_BLOCK
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = "true"
  tags = {
    Name = "${var.PROJECT_NAME}-vpc-public-subnet-2"
  }
}

# private subnet 1
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.VPC_PRIVATE_SUBNET1_CIDR_BLOCK
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "${var.PROJECT_NAME}-vpc-private-subnet-1"
  }
}
# private subnet 2
resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.VPC_PRIVATE_SUBNET2_CIDR_BLOCK
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "${var.PROJECT_NAME}-vpc-private-subnet-2"
  }
}

# internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.PROJECT_NAME}-vpc-internet-gateway"
  }
}

# ELastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.igw]
}

# NAT gateway for private ip address
resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id
  depends_on    = [aws_internet_gateway.igw]
  tags = {
    Name = "${var.PROJECT_NAME}-vpc-NAT-gateway"
  }
}

# Route Table for public Architecture

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.PROJECT_NAME}-public-route-table"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = "${var.PROJECT_NAME}-private-route-table"
  }
}
# Route table for Private subnets


# Route Table association with public subnets
resource "aws_route_table_association" "to_public_subnet1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "to_public_subnet2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public.id
}

# Route table association with private subnets
resource "aws_route_table_association" "to_private_subnet1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "to_private_subnet2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private.id
}
resource "aws_security_group" "demo-sg" {
  name   = "demo-security-group"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "http"
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

  tags = {
    Name = "terraform-Ansible-demo"
  }
}
resource "aws_instance" "firstdemo" {
  key_name                    = aws_key_pair.redhat.key_name
  ami                         = "ami-098f16afa9edf40be"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet_1.id
  associate_public_ip_address = true
  #security_groups = [demo-sg]
  vpc_security_group_ids = [aws_security_group.demo-sg.id]
  #key_name = "newck"
  tags = {
    Name = "demoinstance1"
  }
}

resource "null_resource" "remote" {
  depends_on = [aws_instance.firstdemo]

  provisioner "remote-exec" {
    inline = ["sudo yum install python3 -y"]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        =  aws_instance.firstdemo.public_ip
      private_key = file("~/.ssh/id_rsa")
    }
  }
}

resource "null_resource" "provisioning" {
  depends_on = [aws_instance.firstdemo]

  provisioner "local-exec" {
    command = "sleep 120; ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ec2-user --private-key ../.ssh/id_rsa -i '${aws_instance.firstdemo.public_ip},' nginxplay.yml"
    
  } #command = "echo ${aws_instance.firstdemo.private_ip} >> private_ips.txt"ml
}