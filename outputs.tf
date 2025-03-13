output "instance_ips" {
  description = "Private IP addresses of the Redis EC2 instances"
  value       = aws_instance.redis[*].private_ip
}