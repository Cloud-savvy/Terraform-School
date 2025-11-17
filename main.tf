terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "dev-vpc" {
    cidr_block = var.vpc_cidr_block
    tags = {
        Name = "${var.env_prefix}-vpc"
    }
}

# Create a Subnet
resource "aws_subnet" "dev-subnet" {
    vpc_id = aws_vpc.dev-vpc.id
    cidr_block = var.subnet_cidr_block
    availability_zone = var.avail_zone
    map_public_ip_on_launch = true
    tags = {
        Name = "${var.env_prefix}-subnet"
    }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "dev-igw" {
    vpc_id = aws_vpc.dev-vpc.id
    tags = {
        Name = "${var.env_prefix}-igw"
    }
}

# Create a Route Table
resource "aws_route_table" "dev-route-table" {
    vpc_id = aws_vpc.dev-vpc.id
    
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.dev-igw.id
    }
    tags = {
        Name = "${var.env_prefix}-route-table"
    }
}

# Associate the Route Table with the Subnet
resource "aws_route_table_association" "dev-route-table-assoc" {
    subnet_id      = aws_subnet.dev-subnet.id
    route_table_id = aws_route_table.dev-route-table.id
}

# Create a Security Group
resource "aws_security_group" "dev-sg" {
    name        = "${var.env_prefix}-sg"
    description = "Security group for ${var.env_prefix} environment"
    vpc_id      = aws_vpc.dev-vpc.id

    # SSH access 
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = [var.my_ip]
    }

    # HTTP access
    ingress {
        from_port   = 8080
        to_port     = 8080
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # All outbound traffic
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        prefix_list_ids = []
    }

    tags = {
        Name = "${var.env_prefix}-sg"
    }
}

# Create an EC2 Instance from a Latest Amazon Linux AMI
data "aws_ami" "al-lts-image" {
    most_recent = true
    owners = ["amazon"]
    filter {
        name = "name"
        values = [var.image_name]
    }
    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
}

output "ami_id" {
    value = data.aws_ami.al-lts-image
}

resource "aws_key_pair" "ssh-key" {
    key_name = "devops-key"
    public_key = file(var.public_key_location)
}

resource "aws_instance" "dev-server" {
    ami = data.aws_ami.al-lts-image.id  
    instance_type = var.instance_type
    subnet_id = aws_subnet.dev-subnet.id
    vpc_security_group_ids = [aws_security_group.dev-sg.id]
    availability_zone = var.avail_zone
    associate_public_ip_address = true 
    key_name = aws_key_pair.ssh-key.key_name

    
    tags = {
        Name = "${var.env_prefix}-server"
    }
}

output "instance_public_ip" {
    value = aws_instance.dev-server.public_ip
}