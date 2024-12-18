# Step 1: Generate an SSH key pair using TLS
resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Step 2: Create an AWS Key Pair
resource "aws_key_pair" "example" {
  key_name   = "ec2-key-pramod"
  public_key = tls_private_key.example.public_key_openssh
}

# Step 3: Save the private key locally and set file permissions
resource "local_file" "private_key_pem" {
  content  = tls_private_key.example.private_key_pem
  filename = "/home/pramod/infra/ansible/ec2-key-pramod.pem"

  provisioner "local-exec" {
    command = "chmod 400 /home/pramod/infra/ansible/ec2-key-pramod.pem"
  }
}

# Step 4: Create a VPC with a /28 CIDR block
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/28"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "my-vpc"
  }
}

# Step 5: Create a Public Subnet
resource "aws_subnet" "my_public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/28"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "my-public-subnet"
  }
}

# Step 6: Create an Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "my-igw"
  }
}

# Step 7: Create a Route Table and Associate it with the Public Subnet
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "main-route-table"
  }
}

# Step 8: Associate Route Table with Public Subnet
resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.my_public_subnet.id
  route_table_id = aws_route_table.main.id
}

# Step 9: Create a Security Group for SSH (Port 22)
resource "aws_security_group" "ssh_sg" {
  name        = "ssh_security_group"
  description = "Allow SSH and Ansible inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
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
    Name = "SSH-Security-Group"
  }
}

# Step 10: Create an EC2 Instance in the Public Subnet
resource "aws_instance" "example" {
  ami             = "ami-005fc0f236362e99f"
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.example.key_name
  subnet_id       = aws_subnet.my_public_subnet.id
  vpc_security_group_ids = [aws_security_group.ssh_sg.id]

  tags = {
    Name = "MyEC2Instance"
    Environment = "frontend"
  }
}

# Step 11: Output the Private Key
output "private_key" {
  value     = tls_private_key.example.private_key_pem
  sensitive = true
}

# Output the Public IP of the EC2 instance
output "ec2_public_ip" {
  value = aws_instance.example.public_ip
}

