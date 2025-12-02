output "ec2_public_ip" {
  value = aws_instance.web.public_ip
  description = "EC2 Public IP Address"
}

output "rds_endpoint" {
  value = aws_db_instance.default.address
  description = "RDS Endpoint URL (Use this in Spring config)"
}