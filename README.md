# Taskify AWS Deployment

This Terraform configuration sets up the infrastructure for deploying the Taskify application on AWS, including:

- EC2 instance for hosting both backend and frontend applications
- RDS MySQL database in a private subnet
- VPC with public and private subnets
- Security groups and networking configuration

## Prerequisites

1. [Terraform](https://www.terraform.io/downloads.html) installed
2. AWS CLI installed and configured with appropriate credentials
3. An existing EC2 key pair for SSH access

## Setup Instructions

1. **Create a key pair in AWS EC2** (if you don't already have one)
   - Go to EC2 Dashboard > Key Pairs > Create Key Pair
   - Name it (e.g., "taskify-key") and download the .pem file
   - Secure the .pem file (chmod 400 taskify-key.pem on Linux/Mac)

2. **Configure your variables**
   - Copy the example variables file: `cp terraform.tfvars.example terraform.tfvars`
   - Edit `terraform.tfvars` with your specific values

3. **Initialize Terraform**
   ```bash
   terraform init
   ```

4. **Plan the deployment**
   ```bash
   terraform plan
   ```

5. **Apply the configuration**
   ```bash
   terraform apply
   ```

6. **Access your EC2 instance**
   ```bash
   ssh -i taskify-key.pem ec2-user@<ec2_public_ip>
   ```

## Deployment

After the infrastructure is set up, you need to:

1. Update your GitHub repository URLs in the deployment script on the EC2 instance
2. Run the deployment script:
   ```bash
   sudo /home/ec2-user/deploy.sh
   ```

## Customization

- **Nginx Configuration**: The default Nginx configuration routes `/api` to the backend and everything else to the frontend. Modify `/etc/nginx/conf.d/taskify.conf` if needed.
- **Application Ports**: By default, the backend runs on port 3000 and the frontend on port 3001. Update the Nginx configuration and security groups if you use different ports.

## Security Considerations

- The current configuration allows SSH access from any IP. For production, restrict this to your specific IP address.
- Consider setting up HTTPS with Let's Encrypt for production.
- Use AWS Secrets Manager for sensitive information instead of hardcoding in terraform.tfvars.

## Cleanup

To destroy all created resources:

```bash
terraform destroy
```