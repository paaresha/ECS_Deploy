resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.name_prefix}-vpc"
    Project     = var.tags["Project"]
    Environment = var.tags["Environment"]
    GitCommit   = var.tags["GitCommit"]
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name        = "${var.name_prefix}-igw"
    Project     = var.tags["Project"]
    Environment = var.tags["Environment"]
    GitCommit   = var.tags["GitCommit"]
  }
}

resource "aws_subnet" "public" {
  for_each = toset(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.key
  availability_zone       = var.availability_zones[index(var.public_subnet_cidrs, each.key)]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.name_prefix}-public-${var.availability_zones[index(var.public_subnet_cidrs, each.key)]}"
    Tier        = "public"
    Project     = var.tags["Project"]
    Environment = var.tags["Environment"]
    GitCommit   = var.tags["GitCommit"]
  }
}

resource "aws_subnet" "private" {
  for_each = toset(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.key
  availability_zone = var.availability_zones[index(var.private_subnet_cidrs, each.key)]

  tags = {
    Name        = "${var.name_prefix}-private-${var.availability_zones[index(var.private_subnet_cidrs, each.key)]}"
    Tier        = "private"
    Project     = var.tags["Project"]
    Environment = var.tags["Environment"]
    GitCommit   = var.tags["GitCommit"]
  }
}

resource "aws_eip" "nat" {
  for_each = var.enable_nat_gateway ? toset(var.public_subnet_cidrs) : toset([])

  domain = "vpc"

  tags = {
    Name        = "${var.name_prefix}-eip-${var.availability_zones[index(var.public_subnet_cidrs, each.key)]}"
    Project     = var.tags["Project"]
    Environment = var.tags["Environment"]
    GitCommit   = var.tags["GitCommit"]
  }
}

resource "aws_nat_gateway" "this" {
  for_each = var.enable_nat_gateway ? toset(var.public_subnet_cidrs) : toset([])

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id
  depends_on    = [aws_internet_gateway.this]

  tags = {
    Name        = "${var.name_prefix}-nat-${var.availability_zones[index(var.public_subnet_cidrs, each.key)]}"
    Project     = var.tags["Project"]
    Environment = var.tags["Environment"]
    GitCommit   = var.tags["GitCommit"]
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name        = "${var.name_prefix}-rtb-public"
    Project     = var.tags["Project"]
    Environment = var.tags["Environment"]
    GitCommit   = var.tags["GitCommit"]
  }
}

resource "aws_route_table_association" "public" {
  for_each = toset(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  for_each = toset(var.private_subnet_cidrs)

  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [each.key] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.this[var.public_subnet_cidrs[index(var.private_subnet_cidrs, each.key)]].id
    }
  }

  tags = {
    Name        = "${var.name_prefix}-rtb-private-${var.availability_zones[index(var.private_subnet_cidrs, each.key)]}"
    Project     = var.tags["Project"]
    Environment = var.tags["Environment"]
    GitCommit   = var.tags["GitCommit"]
  }
}

resource "aws_route_table_association" "private" {
  for_each = toset(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-sg-alb"
  description = "Allow HTTP/HTTPS from the internet to the ALB"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound"
  }

  tags = {
    Name        = "${var.name_prefix}-sg-alb"
    Project     = var.tags["Project"]
    Environment = var.tags["Environment"]
    GitCommit   = var.tags["GitCommit"]
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.name_prefix}-sg-ecs"
  description = "Allow traffic from ALB to ECS tasks on container port"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Traffic from ALB only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound (ECR pull, CloudWatch, etc.)"
  }

  tags = {
    Name        = "${var.name_prefix}-sg-ecs"
    Project     = var.tags["Project"]
    Environment = var.tags["Environment"]
    GitCommit   = var.tags["GitCommit"]
  }
}
