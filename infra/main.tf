resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    name = var.vpc_name
  }
}

resource "aws_subnet" "subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, 1)
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    name = var.subnet_name
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = var.igw_name
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  tags = {
    name = var.route_table_name
  }
}

resource "aws_route_table_association" "subnet_route" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_security_group" "ec2_sg" {
    name = var.sg_name
    description = "Allow ingress traffic on ports 22 and 80"

    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = var.sg_name
    }
}

resource "aws_instance" "ec2" {
    ami = "ami-0ecb62995f68bb549"	# Ubuntu Server 24.04 LTS
    instance_type = "t2.micro"
    key_name = "teste-key"
    vpc_security_group_ids = [aws_security_group.ec2_sg.id]

    user_data = <<-EOF
                #!/bin/bash

                # Atualiza pacotes
                apt-get update -y

                # Instala dependências
                apt-get install -y curl

                # Instala Docker usando script oficial
                curl -fsSL https://get.docker.com | bash

                # Habilita e inicia o serviço
                systemctl enable docker
                systemctl start docker

                # Adiciona o usuário padrão ao grupo docker
                usermod -aG docker ubuntu
                EOF
    
    tags = {
        Name = var.instance_name
    }
}

output "public_ip" {
  value       = aws_instance.ec2.public_ip
}