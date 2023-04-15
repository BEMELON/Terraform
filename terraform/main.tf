terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  # Asia/Seoul
  region = "ap-northeast-2"
}

resource "aws_instance" "app_server" {
  ami           = "ami-04cebc8d6c4f297a3"
  instance_type = "t2.micro"

  tags = {
    Name = "ExampleAppServerInstance"
  }
}
