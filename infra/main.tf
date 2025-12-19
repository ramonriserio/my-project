resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    name = var.vpc_name
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24" 
  map_public_ip_on_launch = true          # Garante IP público para baixar Docker
  availability_zone       = "us-east-1a"  

  tags = {
    Name = var.subnet_name
  }
}

# Liga a Subnet à Rota de Internet
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.route_table.id
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

resource "aws_security_group" "ec2_sg2" {
    name = var.sg_name
    description = "Allow ingress traffic on ports 22 and 80"
    vpc_id      = aws_vpc.main.id

    ingress {
        description = "SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "HTTP"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "HTTPS"
        from_port = 443
        to_port = 443
        protocol = "tcp"
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

# 1. Gerar a Chave Privada (Private Key)
resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# 2. Criar o Certificado Autoassinado
resource "tls_self_signed_cert" "self_signed" {
  # Usa a chave gerada acima
  private_key_pem = tls_private_key.private_key.private_key_pem

  # Configurações do certificado
  subject {
    common_name  = "meu-app-interno.local"
    organization = "Minha Empresa"
  }

  validity_period_hours = 8760 # Validade de 1 ano
  
  # Permissões do certificado (importante para funcionar como HTTPS)
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_instance" "ec2" {
    ami = "ami-0ecb62995f68bb549"	# Ubuntu Server 24.04 LTS
    instance_type = "t2.micro"
    key_name = "teste-key"

    # CORREÇÃO: Especificar a subnet
    subnet_id              = aws_subnet.public_subnet.id
    vpc_security_group_ids = [aws_security_group.ec2_sg2.id]

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

                # Ir para pasta do usuário
                cd /home/ubuntu

                # Injetar os Certificados gerados pelo Terraform
                echo "${tls_private_key.private_key.private_key_pem}" > server.key
                echo "${tls_self_signed_cert.self_signed.cert_pem}" > server.crt

                # Ajusta permissões para o usuário ubuntu conseguir ler/editar se precisar
                chown ubuntu:ubuntu server.key server.crt
                chmod 600 server.key

                EOF
    
    tags = {
        Name = var.instance_name
    }
}

output "public_ip" {
  value       = aws_instance.ec2.public_ip
}