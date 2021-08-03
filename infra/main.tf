# data "aws_ami" "ubuntu" {
#   most_recent = true

#   filter {
#     name   = "name"
#     values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
#   }

#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }

#   owners = ["099720109477"]
# }


resource "aws_vpc" "test-vpc-01" {
  cidr_block           = "10.15.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Environment = "test"
    Name        = "test-vpc-01"
  }
}

resource "aws_internet_gateway" "test-igw-01" {
  vpc_id = aws_vpc.test-vpc-01.id

  tags = {
    Environment = "test"
    Name        = "test-igw-01"
  }
}

resource "aws_route_table" "test-pub-rt-01" {
  vpc_id = aws_vpc.test-vpc-01.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test-igw-01.id
  }
  tags = {
    Name = "test-pub-rt-01"
  }
}

# SUBNETS
resource "aws_subnet" "test-pub-subnet-01" {
  vpc_id            = aws_vpc.test-vpc-01.id
  cidr_block        = "10.15.10.0/24"
  availability_zone = "us-west-2a"
  tags = {
    Name = "test-subnet-01"
  }
}

resource "aws_route_table_association" "test-rt-association-01" {
  subnet_id      = aws_subnet.test-pub-subnet-01.id
  route_table_id = aws_route_table.test-pub-rt-01.id
}

resource "aws_subnet" "test-pub-subnet-02" {
  vpc_id            = aws_vpc.test-vpc-01.id
  cidr_block        = "10.15.20.0/24"
  availability_zone = "us-west-2b"
  tags = {
    Name = "test-subnet-02"
  }
}

resource "aws_route_table_association" "test-rt-association-02" {
  subnet_id      = aws_subnet.test-pub-subnet-02.id
  route_table_id = aws_route_table.test-pub-rt-01.id
}

# LOAD BALANCER
resource "aws_lb" "test-lb-01" {
  name               = "test-lb-01"
  load_balancer_type = "application"
  subnets = [
    "${aws_subnet.test-pub-subnet-01.id}", "${aws_subnet.test-pub-subnet-02.id}"
  ]
  security_groups           = ["${aws_security_group.elb_http.id}"]
  internal                  = false
  tags = {
    Environment = "test"
    Name        = "test-elb-01"
  }
}

resource "aws_lb_target_group" "my_alb_target_group" {
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.test-vpc-01.id

  tags = {    
    name = "alb_target_group"    
  }   
  stickiness { 
    type            = "lb_cookie"    
    cookie_duration = 1800    
    enabled         = true 
  }   
  health_check { 
    healthy_threshold   = 2    
    unhealthy_threshold = 10    
    timeout             = 20
    interval            = 30   
    path                = "/"    
    port                = 8080
    matcher = "200"
  }
}

resource "aws_lb_listener" "my_alb_listener" {
  load_balancer_arn = aws_lb.test-lb-01.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_alb_target_group.arn
  }
}

# SECURITY GROUPS
resource "aws_security_group" "elb_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound connections"
  vpc_id      = aws_vpc.test-vpc-01.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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
    Name = "Allow HTTP Security Group"
  }
}

# LAUNCH CONFIGURATION
resource "aws_launch_configuration" "test-lc-01" {
  name                        = "test-lc-01"
  # image_id = data.aws_ami.ubuntu.id
  image_id = "ami-083ac7c7ecf9bb9b0"
  instance_type               = "t2.micro"
  key_name                    = var.key_pair
  security_groups             = ["${aws_security_group.test-autoscaling-sg-01.id}"]
  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }

  user_data = file("deployment.sh")

}

resource "aws_security_group" "test-autoscaling-sg-01" {
  name        = "test-autoscaling-sg-01"
  description = "AutoScaling-Security-Group-1"
  vpc_id      = aws_vpc.test-vpc-01.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# AUTO SCALING
resource "aws_autoscaling_group" "test-asg-01" {
  desired_capacity     = 2
  launch_configuration = aws_launch_configuration.test-lc-01.id
  max_size             = 2
  min_size             = 2
  name                 = "test-asg-01"
  vpc_zone_identifier  = ["${aws_subnet.test-pub-subnet-01.id}", "${aws_subnet.test-pub-subnet-02.id}"]

  health_check_type = "ELB"

  target_group_arns = [aws_lb_target_group.my_alb_target_group.arn]

  timeouts {
    delete = "15m"
  }
  lifecycle {
    create_before_destroy = true
  }

  force_delete = true

  tags = [
    {
      key                 = "Environment"
      value               = "test"
      propagate_at_launch = true
    },
    {
      key                 = "Name"
      value               = "test-server-01"
      propagate_at_launch = true
    }
  ]
}

resource "aws_autoscaling_attachment" "test-autoscaling_attachment" {
  alb_target_group_arn   = aws_lb_target_group.my_alb_target_group.arn
  autoscaling_group_name = aws_autoscaling_group.test-asg-01.id
}

output "elb_dns_name" {
  value = aws_lb.test-lb-01.dns_name
}
