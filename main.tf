#VPC Creation
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
#Target group craetion
resource "aws_lb_target_group" "tg"{
    name = "tg"
    port = 80 
    protocol = "http"
    vpc_id = aws_vpc.main.id
}
