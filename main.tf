provider "aws" {
  region = var.region
}

# Create a VPC
resource "aws_vpc" "taskify_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "taskify-vpc"
  }
}

# Create subnets in different availability zones
resource "aws_subnet" "taskify_public_subnet" {
  vpc_id                  = aws_vpc.taskify_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "taskify-public-subnet"
  }
}

resource "aws_subnet" "taskify_private_subnet_1" {
  vpc_id            = aws_vpc.taskify_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.region}a"
  tags = {
    Name = "taskify-private-subnet-1"
  }
}

resource "aws_subnet" "taskify_private_subnet_2" {
  vpc_id            = aws_vpc.taskify_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.region}b"
  tags = {
    Name = "taskify-private-subnet-2"
  }
}

# Create an internet gateway for the VPC
resource "aws_internet_gateway" "taskify_igw" {
  vpc_id = aws_vpc.taskify_vpc.id
  tags = {
    Name = "taskify-igw"
  }
}

# Create a route table for the public subnet
resource "aws_route_table" "taskify_public_rt" {
  vpc_id = aws_vpc.taskify_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.taskify_igw.id
  }
  tags = {
    Name = "taskify-public-rt"
  }
}

# Associate the public route table with the public subnet
resource "aws_route_table_association" "taskify_public_rta" {
  subnet_id      = aws_subnet.taskify_public_subnet.id
  route_table_id = aws_route_table.taskify_public_rt.id
}

# Create a security group for the EC2 instance
resource "aws_security_group" "taskify_ec2_sg" {
  name        = "taskify-ec2-sg"
  description = "Security group for Taskify EC2 instance"
  vpc_id      = aws_vpc.taskify_vpc.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict to your IP in production
  }

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Next.js default port
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Frontend app port (if different)
  ingress {
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "taskify-ec2-sg"
  }
}

# Create a security group for RDS
resource "aws_security_group" "taskify_db_sg" {
  name        = "taskify-db-sg"
  description = "Allow MySQL access from EC2 instance only"
  vpc_id      = aws_vpc.taskify_vpc.id

  # MySQL access from EC2 security group only
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.taskify_ec2_sg.id]
  }

  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "taskify-db-sg"
  }
}

# Create a subnet group for RDS
resource "aws_db_subnet_group" "taskify_db_subnet_group" {
  name       = "taskify-db-subnet-group"
  subnet_ids = [aws_subnet.taskify_private_subnet_1.id, aws_subnet.taskify_private_subnet_2.id]
  tags = {
    Name = "Taskify DB Subnet Group"
  }
}

# Create the RDS instance in the private subnet
resource "aws_db_instance" "taskify_db" {
  identifier             = "taskify-db"
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_class
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = "default.mysql8.0"
  db_subnet_group_name   = aws_db_subnet_group.taskify_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.taskify_db_sg.id]
  publicly_accessible    = false # Not accessible from the internet
  skip_final_snapshot    = true  # Set to false for production
  
  tags = {
    Name = "Taskify Database"
  }
}

# Create an EC2 instance
resource "aws_instance" "taskify_ec2" {
  ami                    = var.ec2_ami # Amazon Linux 2 AMI
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.taskify_public_subnet.id
  vpc_security_group_ids = [aws_security_group.taskify_ec2_sg.id]
  key_name               = var.key_pair_name
  
  # User data script to install necessary software
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y git
    
    # Install Node.js
    curl -sL https://rpm.nodesource.com/setup_16.x | bash -
    yum install -y nodejs
    
    # Install PM2 for process management
    npm install -g pm2
    
    # Install Nginx
    amazon-linux-extras install nginx1 -y
    systemctl start nginx
    systemctl enable nginx
    
    # Configure Nginx as a reverse proxy (basic config, customize as needed)
    cat > /etc/nginx/conf.d/taskify.conf << 'EOL'
    server {
        listen 80;
        server_name _;
        
        # Backend API (Next.js)
        location /api {
            proxy_pass http://localhost:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
        }
        
        # Frontend app
        location / {
            proxy_pass http://localhost:3001;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
        }
    }
    EOL
    
    systemctl restart nginx
    
    # Create a deployment script
    cat > /home/ec2-user/deploy.sh << 'EOL'
    #!/bin/bash
    
    # Clone or pull the backend repository
    if [ -d "/home/ec2-user/taskify-backend" ]; then
      cd /home/ec2-user/taskify-backend
      git pull
    else
      git clone https://github.com/yourusername/taskify-backend.git /home/ec2-user/taskify-backend
    fi
    
    # Set up backend
    cd /home/ec2-user/taskify-backend
    npm install
    npm run build
    
    # Update environment variables
    cat > /home/ec2-user/taskify-backend/.env << 'ENV'
    JWT_SECRET=${var.jwt_secret}
    DB_HOST=${aws_db_instance.taskify_db.address}
    DB_USER=${var.db_username}
    DB_PASSWORD=${var.db_password}
    DB_NAME=${var.db_name}
    DB_PORT=3306
    ENV
    
    # Start or restart the backend
    pm2 start npm --name "taskify-backend" -- start || pm2 restart taskify-backend
    
    # Clone or pull the frontend repository
    if [ -d "/home/ec2-user/taskify-frontend" ]; then
      cd /home/ec2-user/taskify-frontend
      git pull
    else
      git clone https://github.com/yourusername/taskify-frontend.git /home/ec2-user/taskify-frontend
    fi
    
    # Set up frontend
    cd /home/ec2-user/taskify-frontend
    npm install
    npm run build
    
    # Start or restart the frontend
    pm2 start npm --name "taskify-frontend" -- start || pm2 restart taskify-frontend
    
    # Save PM2 process list
    pm2 save
    EOL
    
    chmod +x /home/ec2-user/deploy.sh
    
    # Set up PM2 to start on boot
    pm2 startup
    env PATH=$PATH:/usr/bin pm2 startup systemd -u ec2-user --hp /home/ec2-user
  EOF
  
  tags = {
    Name = "Taskify EC2 Instance"
  }
}

# Output the EC2 public IP and RDS endpoint
output "ec2_public_ip" {
  value = aws_instance.taskify_ec2.public_ip
}

output "rds_endpoint" {
  value = aws_db_instance.taskify_db.address
}

output "connection_instructions" {
  value = "Connect to your EC2 instance: ssh -i ${var.key_pair_name}.pem ec2-user@${aws_instance.taskify_ec2.public_ip}"
}