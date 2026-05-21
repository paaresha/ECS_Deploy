output "vpc_id"               { value = aws_vpc.this.id }
output "public_subnet_ids"   { value = [for s in aws_subnet.public  : s.id] }
output "private_subnet_ids"  { value = [for s in aws_subnet.private : s.id] }
output "alb_sg_id"           { value = aws_security_group.alb.id }
output "ecs_tasks_sg_id"     { value = aws_security_group.ecs_tasks.id }
