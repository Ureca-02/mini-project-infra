output "ec2_public_ip" {

  # 탄력적 IP 주소를 출력
  value       = aws_eip.web_eip.public_ip
  description = "Fixed Public IP Address (Elastic IP)"
}

output "rds_endpoint" {
  value       = aws_db_instance.default.address
  description = "RDS Endpoint URL"
}