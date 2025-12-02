# -------------------------------------------------------------
# 1. 데이터 소스 (Data Sources) - AWS에서 정보 가져오기
# -------------------------------------------------------------

# 기본 VPC 정보 가져오기
data "aws_vpc" "default" {
  default = true
}

# 기본 서브넷 정보 가져오기
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 최신 Ubuntu 24.04 LTS AMI ID 동적으로 가져오기
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -------------------------------------------------------------
# 2. 보안 그룹 (Security Groups)
# -------------------------------------------------------------

# 2-1. EC2용 보안 그룹 (웹 서버)
resource "aws_security_group" "web_sg" {
  name        = "web-server-sg"
  description = "Allow SSH (22) and HTTP (80)"
  vpc_id      = data.aws_vpc.default.id

  # SSH 접속 (22)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 보안을 위해 본인 IP로 제한 권장
  }

  # HTTP 접속 (80) - Nginx가 받아서 8080으로 넘김
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 아웃바운드 (모두 허용)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2-2. RDS용 보안 그룹 (DB)
resource "aws_security_group" "db_sg" {
  name        = "rds-db-sg"
  description = "Allow MySQL access from EC2 only"
  vpc_id      = data.aws_vpc.default.id

  # EC2 보안 그룹에서의 접근만 허용 (보안 강화)
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }
}

# -------------------------------------------------------------
# 3. RDS 인스턴스 (MySQL)
# -------------------------------------------------------------
resource "aws_db_instance" "default" {
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro" # 프리티어/크레딧 호환
  db_name                = "mydb"
  username               = "admin"
  password               = var.db_password
  parameter_group_name   = "default.mysql8.0"
  skip_final_snapshot    = true          # 종료 시 스냅샷 생성 안함 (빠른 삭제)
  publicly_accessible    = false         # 외부 접근 차단
  vpc_security_group_ids = [aws_security_group.db_sg.id]
}

# -------------------------------------------------------------
# 4. EC2 인스턴스 (Web Server)
# -------------------------------------------------------------
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id # 위에서 찾은 최신 AMI 사용
  instance_type = "t3.small"             # 2vCPU, 2GB RAM
  key_name      = var.key_name           # 변수로 받은 키 페어 이름

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # 디스크 용량 설정 (기본 8GB -> 20GB로 넉넉하게)
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  # -----------------------------------------------------------
  # 사용자 데이터 (User Data) - 초기 세팅 스크립트
  # -----------------------------------------------------------
  user_data = <<-EOF
              #!/bin/bash
              
              # 1. 시스템 업데이트 및 Docker 설치
              apt-get update
              apt-get install -y docker.io docker-compose
              usermod -aG docker ubuntu

              # 2. Swap 메모리 설정 (2GB) - OOM 방지
              if [ ! -f /swapfile ]; then
                  fallocate -l 2G /swapfile
                  chmod 600 /swapfile
                  mkswap /swapfile
                  swapon /swapfile
                  echo '/swapfile none swap sw 0 0' >> /etc/fstab
              fi

              # 3. Nginx 설치
              apt-get install -y nginx

              EOF

  tags = {
    Name = "My-Spring-Server"
  }
}