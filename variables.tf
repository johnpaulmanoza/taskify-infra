variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "db_username" {
  description = "Database administrator username"
  default     = "taskify_admin"
  sensitive   = true
}

variable "db_password" {
  description = "Database administrator password"
  sensitive   = true
}

variable "db_name" {
  description = "Name of the database to create"
  default     = "taskify_db"
}

variable "db_instance_class" {
  description = "RDS instance class"
  default     = "db.t3.micro"
}

variable "ec2_ami" {
  description = "AMI ID for EC2 instance"
  default     = "ami-0c02fb55956c7d316" # Amazon Linux 2 AMI in us-east-1, update for your region
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "key_pair_name" {
  description = "Name of the key pair to use for SSH access"
  default     = "taskify-key"
}

variable "jwt_secret" {
  description = "Secret key for JWT signing"
  default     = "your-secret-key-at-least-32-characters"
  sensitive   = true
}