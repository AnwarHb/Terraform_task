terraform {
    # aws provider
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 4.0"
        }
     }
}
# Configure the AWS Provider
provider "aws" {
  region =  "eu-central-1"
}
# Create VPC 
resource "aws_vpc" "task" {
  cidr_block       = "10.10.0.0/16"
  tags = {
    Name = "task-vpc"
  }
}
# Create an internet gateway for the vpc
resource "aws_internet_gateway" "gw_task" {
  vpc_id = aws_vpc.task.id
  tags = {
    "Name" = "task-gw"
  }
}
# Create the public Subnet
resource "aws_subnet" "public-subnet" {
  vpc_id                  = aws_vpc.task.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}
# Create a public route table
resource "aws_route_table" "rt-public" {
  vpc_id = aws_vpc.task.id
  route {
    # from everywhere to the gateway of the VPC
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw_task.id
  }
}
# Attach the route table to the public subnet
resource "aws_route_table_association" "ass-rt-public" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.rt-public.id
}
# Create the private subnet 
resource "aws_subnet" "subnet-private" {
  vpc_id            = aws_vpc.task.id
  cidr_block        = "10.10.2.0/24"
  availability_zone = "eu-central-1b"
  tags = {
    Name = "subnet-task-private"
  }
}
# Create an elastic Ip for the NAT 
resource "aws_eip" "NAT-IP" {
  # eip is in the VPC and depends on the gateway  
  vpc        = true
  depends_on = [aws_internet_gateway.gw_task]
}
# Create a NAT gateway 
resource "aws_nat_gateway" "task-NAT" {
  allocation_id = aws_eip.NAT-IP.id
  subnet_id     = aws_subnet.public-subnet.id
}
# Create a private route table for the private subnet
resource "aws_route_table" "rt-private" {
  vpc_id = aws_vpc.task.id
  route {
    # traffic from everywhere to the NAT gateway
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.task-NAT.id
  }
}
# Associate the private route table to the private subnet
resource "aws_route_table_association" "rt-private-ass" {
  route_table_id = aws_route_table.rt-private.id
  subnet_id      = aws_subnet.subnet-private.id
}
#Create TLS key to allow SSH 
resource "tls_private_key" "new-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
# Create a key 
resource "aws_key_pair" "ssh-key" {
  key_name   = "newSSHkey"
  public_key = tls_private_key.new-key.public_key_openssh
}
#Create a file with the ssh key with the name newSSHkey
resource "local_file" "ssh_key_pem" {
  filename = "${path.module}/newSSHkey.pem"
  content  = tls_private_key.new-key.private_key_pem
}
######## Creatr SQL instance ########
# Create a security group for the instance
resource "aws_security_group" "allow-sql" {
  name        = "allow_mysql"
  description = "allow inbound traffic for mysql instance"
  vpc_id      = aws_vpc.task.id
  # In traffic
  ingress {
    description = "mysql-in"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "ssh-in"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  #out traffic
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "allow_mysql"
  }
}
# Create a network interface
resource "aws_network_interface" "eni-sql" {
  subnet_id       = aws_subnet.subnet-private.id
  security_groups = [aws_security_group.allow-sql.id]
  tags = {
    Name = "Network interface"
  }
}
#Create an EC2 instance for SQL
resource "aws_instance" "inst-mysql"{
  ami           = "ami-065deacbcaac64cf2"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.ssh-key.key_name
  network_interface {
    network_interface_id = aws_network_interface.eni-sql.id
    device_index         = 0
  }
    tags = {
    Name = "sql-server"
  }

  user_data  = "${file("scripts/sql.sh")}"
  depends_on = [ aws_network_interface.eni-sql,aws_nat_gateway.task-NAT,aws_route_table_association.rt-private-ass]
} 
######## WordPress Instance ########
resource "aws_security_group" "allow-web" {
  name        = "allow_web"
  description = "allow inbound web traffic"
  vpc_id      = aws_vpc.task.id
  #In 
  ingress {
    description = "Web"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  #out
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "allow_web"
  }
}
# Create a network interface for wordpress
resource "aws_network_interface" "eni-web" {
  subnet_id       = aws_subnet.public-subnet.id
  security_groups = [aws_security_group.allow-web.id]
  tags = {
    Name = "nerwork-interface-wordpress"
  }
}
# Create the EC2 instance for wordpress
resource "aws_instance" "ec2-web" {
  ami           = "ami-065deacbcaac64cf2"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.ssh-key.key_name
  network_interface {
    network_interface_id = aws_network_interface.eni-web.id
    device_index         = 0
  }
  tags = {
    Name = "wordpress-server"
  }
  user_data  = "${file("scripts/wordpress.sh")}"
  depends_on = [aws_internet_gateway.gw_task]
}
#outputs 
output "sql-private-ip"{
  value = aws_instance.inst-mysql.private_ip
}
output "wp-public-ip"{
  value = aws_instance.ec2-web.public_ip
}

