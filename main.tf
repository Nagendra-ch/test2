
provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

resource "aws_instance" "firstdemo" {
  key_name                    = "nag-NVirginia"
  ami                         = "ami-098f16afa9edf40be"
  instance_type               = "t2.micro"
  #vpc_security_group_ids = 	 [aws_security_group.SSH-RDS-Connection.id]
  #vpc_id = aws_vpc.default.id
  #subnet_id                   = aws_subnet.first.id
  associate_public_ip_address = true

  provisioner "remote-exec" {
    inline = [
      "sudo yum -y install python3-pip",
      "sudo pip3 install ansible --user",
      "sudo yum install git -y",
      "git clone https://github.com/Nagendra-ch/test2.git /tmp/ans",
      "sleep 60; ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook /tmp/ans/ngnixplay.yml"
      ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      host        =  self.public_ip
      private_key = var.keyfile
    }
  }
}