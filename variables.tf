variable "db_password" {
  description = "RDS root password"
  type        = string
  sensitive   = true # 터미널에 로그가 남지 않게 설정
}

variable "key_name" {
  description = "Name of the EC2 Key Pair to allow SSH access"
  type        = string
  default     = "my-key"
}