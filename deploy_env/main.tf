terraform {
  backend "s3" {
    bucket         = "myawsbucket1108"
    key            = "Users/rushikeshgunjal/Desktop/Study/Terraform/terraform.tfstate.d/Dev/terraform.tfstate"
    region         = "us-east-1" # Change to your desired region
  }
}
resource "aws_security_group" "allow_ssh" {
  name_prefix = "allow_ssh_"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Replace with a more restrictive CIDR block if needed
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "dev-auth" {
  key_name = "dev-key"
  public_key = file("~/.ssh/id_ed25519.pub")
}

resource "aws_instance" "tf1" {
  count             = 1
  ami               = var.ami-id
  instance_type     = var.instance_type
  key_name          = "dev-key"  # Ensure this matches the key pair name in AWS
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  user_data         = file("userdata.tpl")
  tags = {
    Name = "Dev"
  }
}

# Output public IP addresses
output "instance_ips" {
  value = aws_instance.tf1[*].public_ip
}
