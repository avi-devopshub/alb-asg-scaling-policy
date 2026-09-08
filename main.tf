#VPC Creation
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
}
#public_subnet_1a
resource "aws_subnet" "public_subnet_1a" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.0.0/20"
  availability_zone = "ap-south-2a"
  tags = {
    Name = "public_subnet_1a"
  }
}
#public_subnet_2b
resource "aws_subnet" "public_subnet_2b" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.16.0/20"
  availability_zone = "ap-south-2b"
  tags = {
    Name = "public_subnet_2b"
  }
} 
#internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "igw"
  }
}
#public route table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id
  route{
    gateway_id = aws_internet_gateway.igw.id
    cidr_block = "0.0.0.0/0"
  }
  tags = {
    Name = "public_rt"
  }
}
#public rt association
resource "aws_route_table_association" "public_rt_association" {
  for_each = {
    public_1a = aws_subnet.public_subnet_1a.id
    public_2b = aws_subnet.public_subnet_2b.id
  }
  route_table_id = aws_route_table.public_rt.id
  subnet_id = each.value
}
#Security Group for ALB
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.vpc.id
  name = "alb_sg"
  description = "alb_sg"
  ingress{
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress{
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}
#Security Group for Launch Template
resource "aws_security_group" "lt_sg" {
  name        = "app_sg"
  description = "Security group for application servers"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
#Target group craetion
resource "aws_lb_target_group" "tg" {
    vpc_id = aws_vpc.vpc.id
    name = "tg"
    port = 80 
    protocol = "HTTP"
    tags = {
      Name = "tg"
    }
}
#Load Balancer
resource "aws_lb" "alb" {
  name = "alb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb_sg.id]
  subnets = [aws_subnet.public_subnet_1a.id, aws_subnet.public_subnet_2b.id]
   enable_deletion_protection = true
   tags = {
    Name = "alb"
   }
}
#Listener
resource "aws_lb_listener" "backend" {
  load_balancer_arn = aws_lb.alb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}
#ASG creation prerequisites : Launch Template
resource "aws_launch_template" "lt" {
  name = "lt"
  image_id = "ami-0199ac7c9fbf9ed83"
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.lt_sg.id]
  user_data = filebase64("/root/ALB/user_data.sh")
}

#ASG
resource "aws_autoscaling_group" "asg" {
  name = "asg"
  desired_capacity = 2
  max_size = 4
  min_size = 1
  vpc_zone_identifier = [aws_subnet.public_subnet_1a.id, aws_subnet.public_subnet_2b.id]
  target_group_arns = [aws_lb_target_group.tg.arn]
  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "app-server"
    propagate_at_launch = true
  }
}

#ASG Policy
resource "aws_autoscaling_policy" "target_tracking" {
  name = "target-tracking"
  policy_type = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
     target_value = 50.0
  }
}