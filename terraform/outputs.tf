output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.jenkins_agent.public_ip
}
