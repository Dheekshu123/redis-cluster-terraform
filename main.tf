# Create a security group
resource "aws_security_group" "redis_sg" {
  name        = var.security_group_name
  description = "Allow inbound traffic for Redis"

  ingress {
    from_port   = 6379
    to_port     = 6382
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 16379
    to_port     = 16382
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
    Name = var.security_group_name
  }
}

# Create an IAM role for EC2 with EC2 Full Access
resource "aws_iam_role" "redis_ec2_role1" {
  name = var.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach the EC2 Full Access policy to the IAM role
resource "aws_iam_policy_attachment" "ec2_full_access" {
  name       = "${var.iam_role_name}-policy-attachment"
  roles      = [aws_iam_role.redis_ec2_role1.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# Create an IAM instance profile for the role
resource "aws_iam_instance_profile" "redis_ec2_profile" {
  name = var.iam_role_name
  role = aws_iam_role.redis_ec2_role1.name
}

# Launch EC2 instances
resource "aws_instance" "redis" {
  count                = var.instance_count
  ami                  = var.ami_id
  instance_type        = var.instance_type
  key_name             = var.key_name
  security_groups      = [aws_security_group.redis_sg.name]
  iam_instance_profile = aws_iam_instance_profile.redis_ec2_profile.name

  user_data = <<-EOF
                #!/bin/bash
                # Install Docker
                sudo yum install -y docker
                sudo systemctl start docker
                sudo systemctl enable docker
                sudo usermod -aG docker ec2-user

                # Tune system parameters
                echo 'net.core.rmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
                echo 'net.core.wmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
                echo 'net.ipv4.tcp_rmem = 4096 87380 134217728' | sudo tee -a /etc/sysctl.conf
                echo 'net.ipv4.tcp_wmem = 4096 65536 134217728' | sudo tee -a /etc/sysctl.conf
                echo 'net.core.netdev_max_backlog = 300000' | sudo tee -a /etc/sysctl.conf
                echo 'net.core.somaxconn = 65535' | sudo tee -a /etc/sysctl.conf
                echo 'vm.swappiness = 0' | sudo tee -a /etc/sysctl.conf
                sudo sysctl -p

                # Create directories for Redis data and logs
                sudo mkdir -p /opt/redis{1,2,3}
                sudo mkdir -p /var/log/redis{1,2,3}
                sudo chmod -R 777 /opt/redis{1,2,3}
                sudo chmod -R 777 /var/log/redis{1,2,3}

                # Run Redis containers
                sudo docker run -d --net=host --restart=unless-stopped --name redis1 \
                    -v /opt/redis1:/opt/redis -v /var/log/redis1:/var/log/redis \
                    ${var.docker_image} redis-server /usr/local/etc/redis/redis.conf \
                    --port 6379 --requirepass ${var.redis_password}
                
                sudo docker run -d --net=host --restart=unless-stopped --name redis2 \
                    -v /opt/redis2:/opt/redis -v /var/log/redis2:/var/log/redis \
                    ${var.docker_image} redis-server /usr/local/etc/redis/redis.conf \
                    --port 6380 --requirepass ${var.redis_password}
                
                sudo docker run -d --net=host --restart=unless-stopped --name redis3 \
                    -v /opt/redis3:/opt/redis -v /var/log/redis3:/var/log/redis \
                    ${var.docker_image} redis-server /usr/local/etc/redis/redis.conf \
                    --port 6381 --requirepass ${var.redis_password}

                # Wait for containers to stabilize
                sleep 300

                # Fetch all instance IPs from the metadata
                INSTANCE_IPS=$(aws ec2 describe-instances --region "${var.aws_region}" \
                    --query "Reservations[*].Instances[*].PrivateIpAddress" --output text)
                
                IP_PORTS=$(echo "$INSTANCE_IPS" | sed -E 's/([^ ]+)/\1:6379 \1:6380 \1:6381/g')
                echo "IP_PORTS: $IP_PORTS" >> /home/ec2-user/redis_setup.log

                # Create Redis Cluster
                yes "yes" | sudo docker run -i --net=host ${var.docker_image} redis-cli \
                    -a "${var.redis_password}" --cluster create $IP_PORTS --cluster-replicas 3 \
                    >> /home/ec2-user/redis_setup.log

                echo "Redis Cluster Creation Completed" >> /home/ec2-user/redis_setup.log
              EOF

  tags = {
    Name = "q01p01cache10-${count.index + 1}"
  }
}
