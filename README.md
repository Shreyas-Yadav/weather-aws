# Weather Application - AWS Manual Deployment

A single-page weather application with frontend (Nginx) and backend (Node.js/Express) deployed on AWS using Docker containers, ECR, EC2 instances, Auto Scaling Groups, and Application Load Balancers.

> **Deployment Method:** This guide provides step-by-step instructions for **manual deployment** via the AWS Management Console with **dynamic configuration** - no hardcoding required!

## Architecture Overview

```
                                    Internet
                                       |
                                       v
                          Route 53 (yourdomain.com)
                                       |
                                       v
                    ┌──────────────────────────────────────┐
                    │   Frontend ALB (Internet-facing)     │
                    │        Public Subnets 1a & 1b        │
                    └──────────────────┬───────────────────┘
                                       |
                                       v
                    ┌──────────────────────────────────────┐
                    │  Frontend Auto Scaling Group (ASG)   │
                    │    EC2 Instances (Public Subnets)    │
                    │   Running Nginx + Static Frontend    │
                    └──────────────────┬───────────────────┘
                                       |
                              (Nginx proxies /api/*
                               requests to Backend ALB)
                                       |
                                       v
                    ┌──────────────────────────────────────┐
                    │    Backend ALB (Internal Only)       │
                    │       Private Subnets 1a & 1b        │
                    └──────────────────┬───────────────────┘
                                       |
                                       v
                    ┌──────────────────────────────────────┐
                    │   Backend Auto Scaling Group (ASG)   │
                    │   EC2 Instances (Private Subnets)    │
                    │  Running Node.js/Express API Server  │
                    └──────────────────┬───────────────────┘
                                       |
                        (Outbound internet access for
                         ECR pulls & external APIs)
                                       |
                                       v
                        +--------------+--------------+
                        |                             |
                 NAT Gateway 1a                NAT Gateway 1b
                 (Public Subnet 1a)            (Public Subnet 1b)
                        |                             |
                        +-------------+---------------+
                                      |
                                      v
                                  Internet
```

**High Availability Design:**

- **2 Application Load Balancers:** Frontend ALB (internet-facing) and Backend ALB (internal)
- **2 Auto Scaling Groups** across 2 Availability Zones for fault tolerance
- **2 NAT Gateways** (one per AZ) for redundant outbound internet access
- **3 Route Tables** (1 public, 2 private) for independent AZ routing
- Each private subnet routes through its local NAT Gateway

## Features

- Real-time weather data from OpenWeatherMap API
- Responsive single-page application
- Dockerized microservices architecture
- Dynamic configuration using EC2 metadata and AWS Systems Manager Parameter Store
- Health checks for monitoring
- Auto-scaling capabilities
- Load balanced traffic distribution

## Project Structure

```
weather-aws/
├── frontend/
│   ├── index.html          # Main HTML file
│   ├── style.css           # Styling
│   ├── app.js              # Frontend logic
│   ├── nginx.conf.template # Nginx configuration template (dynamic)
│   └── Dockerfile          # Frontend container image
├── backend/
│   ├── server.js           # Express API server
│   ├── package.json        # Node.js dependencies
│   └── Dockerfile          # Backend container image
├── docker-compose.yml      # Local testing configuration
├── .env.example            # Environment variables template
├── .gitignore              # Git ignore file
└── README.md              # This file
```

## Prerequisites

1. AWS Account with appropriate permissions
2. AWS CLI installed and configured
3. Docker installed locally
4. OpenWeatherMap API key (free tier: https://openweathermap.org/api)
5. Domain name registered (optional - can be in Route 53 or external registrar)

## Deployment Overview

This manual deployment guide is divided into **10 phases** with optimized ordering:

1. **Preparation** - Gather information and set up Parameter Store
2. **Network Infrastructure** - VPC, subnets, gateways using AWS VPC Wizard
3. **Security Groups** - Configure firewall rules
4. **IAM Roles** - Set up permissions for EC2 instances
5. **ECR Repositories** - Create repositories and push Docker images
6. **Backend Infrastructure** - Backend ALB, Launch Template, and ASG
7. **Frontend Infrastructure** - Frontend ALB, Launch Template, and ASG
8. **Verification** - Test the complete application
9. **Route 53** - Configure domain DNS (optional)
10. **SSL/TLS Certificate** - Enable HTTPS (optional but recommended)

**Estimated Time:** 2-3 hours for complete setup

**Key Improvement:** All configurations are now dynamic - no hardcoded values in templates!

## Configuration Overview

This project uses **a single nginx.conf file** that works for both local development and AWS production by using environment variable substitution:

| Environment | BACKEND_HOST | BACKEND_PORT | How It's Set |
|------------|--------------|--------------|--------------|
| **Local (Docker Compose)** | `backend` | `3000` | Set in `docker-compose.yml` |
| **Production (AWS)** | `internal-backend-alb-xxx.elb.amazonaws.com` | `80` | Fetched from Parameter Store in user data script |

**nginx.conf uses:** `http://${BACKEND_HOST}:${BACKEND_PORT}/api/`

This dynamically resolves to:

- **Local:** `http://backend:3000/api/` (Docker service name)
- **Production:** `http://internal-backend-alb-xxx.elb.amazonaws.com:80/api/` (AWS ALB)

**Benefits:**

- ✅ One config file for all environments
- ✅ No rebuilding images when backend changes
- ✅ Environment-specific values passed at runtime
- ✅ No hardcoded URLs

## Local Development Setup

### 1. Clone and Setup

```bash
# Navigate to project directory
cd weather-aws

# Copy environment file
cp .env.example .env

# Edit .env and add your OpenWeatherMap API key
# OPENWEATHER_API_KEY=your_actual_api_key_here
```

### 2. Test Locally with Docker Compose

```bash
# Build and start containers
docker-compose up --build

# Access the application
# Frontend: http://localhost
# Backend API: http://localhost:3000/api/weather?city=London
# Backend Health: http://localhost:3000/health
```

**How Local Development Works:**

The `docker-compose.yml` is configured for local development:

- **Frontend container**: Uses environment variables `BACKEND_HOST=backend` and `BACKEND_PORT=3000`
- **nginx.conf**: Dynamically proxies API requests to `http://${BACKEND_HOST}:${BACKEND_PORT}/api/`
- **Docker networking**: Containers communicate using Docker Compose's internal network
- **No AWS resources needed**: Everything runs locally on your machine

This is different from production AWS deployment where:

- Frontend fetches `BACKEND_ALB_DNS` from AWS Systems Manager Parameter Store
- This is converted to `BACKEND_HOST` and `BACKEND_PORT=80` in the user data script
- nginx.conf uses the same variables but points to the internal Application Load Balancer
- Same nginx.conf file works for both environments!

### 3. Stop Local Environment

```bash
docker-compose down
```

### 4. Troubleshooting Local Development

**Frontend container failing to start:**

```bash
# Check frontend logs
docker-compose logs frontend

# Common issue: nginx configuration error
# Make sure nginx.conf uses ${BACKEND_HOST}:${BACKEND_PORT}
# Not ${BACKEND_ALB_DNS} which is for AWS deployment
```

**Backend not accessible from frontend:**

```bash
# Check backend is running
docker-compose ps

# Check backend logs
docker-compose logs backend

# Verify docker-compose.yml has correct environment variables:
# frontend service should have:
#   - BACKEND_HOST=backend
#   - BACKEND_PORT=3000
```

**Rebuilding after code changes:**

```bash
# Rebuild specific service
docker-compose up -d --build frontend

# Or rebuild all services
docker-compose up -d --build
```

---

## AWS Deployment Guide

**Note:** This guide uses the AWS Console for manual deployment. Make sure you're working in your preferred AWS region (e.g., us-east-1) and use the same region throughout the deployment.

---

## Phase 1: Preparation

Before starting the deployment, gather all necessary information and store configuration in AWS Systems Manager Parameter Store. This eliminates hardcoding and makes the deployment dynamic.

### 1.1 Record Your Configuration

Create a text file to track your deployment details:

```bash
# deployment-config.txt

AWS_REGION=us-east-1
AWS_ACCOUNT_ID=<Your 12-digit AWS account ID>
OPENWEATHER_API_KEY=<Your OpenWeatherMap API key>
PROJECT_NAME=weather-app

# These will be filled in during deployment:
BACKEND_ALB_DNS=<Will be created in Phase 6>
FRONTEND_ALB_DNS=<Will be created in Phase 7>
```

**Get your AWS Account ID:**

```bash
# Via AWS CLI
aws sts get-caller-identity --query Account --output text

# Or via AWS Console
# Click your username (top-right) → Account → Account ID
```

### 1.2 Store Configuration in AWS Systems Manager Parameter Store

This allows EC2 instances to dynamically retrieve configuration without hardcoding.

**AWS Console Steps:**

1. Go to **AWS Systems Manager** → **Parameter Store**
2. Create the following parameters (click "Create parameter" for each):

**Parameter 1: OpenWeatherMap API Key**

```bash
Name: /weather-app/openweather-api-key
Type: SecureString
Tier: Standard
Value: <Your OpenWeatherMap API key>
Description: OpenWeatherMap API key for weather data
```

**Parameter 2: AWS Region**

```bash
Name: /weather-app/aws-region
Type: String
Tier: Standard
Value: us-east-1  (or your chosen region)
Description: AWS region for deployment
```

**Parameter 3: Project Name**

```bash
Name: /weather-app/project-name
Type: String
Tier: Standard
Value: weather-app
Description: Project name for resource tagging
```

**Parameter 4: Backend ALB DNS (placeholder - will be updated later)**

```bash
Name: /weather-app/backend-alb-dns
Type: String
Tier: Standard
Value: placeholder
Description: Backend ALB DNS name (will be updated in Phase 6)
```

**Why Parameter Store?**

- ✅ **No hardcoding** - Configuration is centralized
- ✅ **Secure** - API keys stored as SecureString (encrypted)
- ✅ **Dynamic** - EC2 instances fetch values at runtime
- ✅ **Easy updates** - Change values without rebuilding images
- ✅ **Access control** - IAM policies control who can read/write

### 1.3 Create Resource Tracking Document

Keep a document to track resources as you create them:

```markdown
# Weather App Deployment Tracker

## Phase 1: Preparation
- [x] AWS Account ID: 123456789012
- [x] Region: us-east-1
- [x] Parameter Store configured

## Phase 2: Network Infrastructure
- [ ] VPC ID: 
- [ ] Public Subnet 1a ID: 
- [ ] Public Subnet 1b ID: 
- [ ] Private Subnet 1a ID: 
- [ ] Private Subnet 1b ID: 
- [ ] Internet Gateway ID: 
- [ ] NAT Gateway 1a ID: 
- [ ] NAT Gateway 1b ID: 

## Phase 3: Security Groups
- [ ] Frontend ALB SG ID: 
- [ ] Frontend EC2 SG ID: 
- [ ] Backend ALB SG ID: 
- [ ] Backend EC2 SG ID: 

## Phase 4: IAM Roles
- [ ] EC2 Instance Role ARN: 

## Phase 5: ECR Repositories
- [ ] Frontend ECR URI: 
- [ ] Backend ECR URI: 

## Phase 6: Backend Infrastructure
- [ ] Backend Target Group ARN: 
- [ ] Backend ALB DNS: 
- [ ] Backend Launch Template ID: 
- [ ] Backend ASG Name: 

## Phase 7: Frontend Infrastructure
- [ ] Frontend Target Group ARN: 
- [ ] Frontend ALB DNS: 
- [ ] Frontend Launch Template ID: 
- [ ] Frontend ASG Name: 
```

---

## Phase 2: Network Infrastructure Setup

**Note:** This phase uses the AWS "VPC and more" wizard which automatically creates the VPC, subnets, Internet Gateway, NAT Gateways, and route tables in one streamlined operation.

### 2.1 Create VPC with Wizard

**AWS Console Steps:**

1. Go to **VPC Dashboard**
2. Click **"Create VPC"**
3. Select **"VPC and more"** (this creates VPC with networking resources)

**Configure the following settings:**

```bash
Resources to create: VPC and more

Name tag auto-generation:
  Auto-generate: weather-app
  This will prefix all resources with this name

IPv4 CIDR block: 10.0.0.0/16
IPv6 CIDR block: No IPv6 CIDR block

Tenancy: Default

Number of Availability Zones (AZs): 2
  - Select: us-east-1a
  - Select: us-east-1b
  (Choose AZs appropriate for your region)

Number of public subnets: 2
Number of private subnets: 2

Customize subnets CIDR blocks:
  Public subnet CIDR in us-east-1a:  10.0.1.0/24
  Public subnet CIDR in us-east-1b:  10.0.2.0/24
  Private subnet CIDR in us-east-1a: 10.0.11.0/24
  Private subnet CIDR in us-east-1b: 10.0.12.0/24

NAT gateways ($): 1 per AZ
  (Creates 2 NAT Gateways for High Availability)
  Cost: ~$64/month for 2 NAT Gateways

VPC endpoints: None

DNS options:
  ☑ Enable DNS hostnames
  ☑ Enable DNS resolution
```

**Review and Create:**

1. Review the **Preview** pane on the right to verify:
   - 4 Subnets (2 public, 2 private)
   - 3 Route tables (1 public, 2 private)
   - 3 Network connections (1 IGW, 2 NAT Gateways)

2. Click **"Create VPC"**

**Wait 2-3 minutes** for all resources to be created.

### 2.2 Record VPC and Subnet IDs

After creation completes, record the following in your tracking document:

1. Go to **VPC** → **Your VPCs** → Find `weather-app-vpc`
   - Record **VPC ID** (e.g., vpc-0abc123...)

2. Go to **VPC** → **Subnets** → Filter by your VPC
   - Record all 4 **Subnet IDs**:
     - `weather-app-subnet-public1-us-east-1a`
     - `weather-app-subnet-public2-us-east-1b`
     - `weather-app-subnet-private1-us-east-1a`
     - `weather-app-subnet-private2-us-east-1b`

3. Go to **VPC** → **NAT Gateways**
   - Record both **NAT Gateway IDs**

**Verification:**

- ✅ VPC created with DNS hostnames enabled
- ✅ 4 Subnets (2 public with auto-assign public IP enabled, 2 private)
- ✅ Internet Gateway attached
- ✅ 2 NAT Gateways in "Available" state
- ✅ 3 Route tables with correct routes configured

---

## Phase 3: Security Groups Setup

Create 4 security groups for proper security isolation. These security groups reference each other, so create them in order.

### 3.1 Frontend ALB Security Group

**AWS Console Steps:**

1. Go to **EC2** → **Security Groups**
2. Click **"Create security group"**

```bash
Name: weather-frontend-alb-sg
Description: Security group for Frontend Application Load Balancer
VPC: weather-app-vpc

Inbound Rules:
  Rule 1:
    Type: HTTP
    Port: 80
    Source: 0.0.0.0/0
    Description: Allow HTTP from internet
  
  Rule 2:
    Type: HTTPS
    Port: 443
    Source: 0.0.0.0/0
    Description: Allow HTTPS from internet

Outbound Rules:
  (Keep default: All traffic to 0.0.0.0/0)
```

3. Click **"Create security group"**
4. **Record the Security Group ID** (e.g., sg-0abc123...)

### 3.2 Frontend EC2 Security Group

```bash
Name: weather-frontend-sg
Description: Security group for Frontend EC2 instances
VPC: weather-app-vpc

Inbound Rules:
  Rule 1:
    Type: HTTP
    Port: 80
    Source: Custom → Select weather-frontend-alb-sg
    Description: Allow HTTP from Frontend ALB
  
  Rule 2:
    Type: SSH
    Port: 22
    Source: My IP
    Description: Allow SSH for debugging (optional)

Outbound Rules:
  (Keep default: All traffic to 0.0.0.0/0)
```

**Record the Security Group ID**

### 3.3 Backend ALB Security Group

```bash
Name: weather-backend-alb-sg
Description: Security group for Backend Application Load Balancer (Internal)
VPC: weather-app-vpc

Inbound Rules:
  Rule 1:
    Type: HTTP
    Port: 80
    Source: Custom → Select weather-frontend-sg
    Description: Allow HTTP from Frontend EC2 instances

Outbound Rules:
  (Keep default: All traffic to 0.0.0.0/0)
```

**Record the Security Group ID**

### 3.4 Backend EC2 Security Group

```bash
Name: weather-backend-sg
Description: Security group for Backend EC2 instances
VPC: weather-app-vpc

Inbound Rules:
  Rule 1:
    Type: Custom TCP
    Port: 3000
    Source: Custom → Select weather-backend-alb-sg
    Description: Allow traffic from Backend ALB
  
  Rule 2:
    Type: SSH
    Port: 22
    Source: My IP
    Description: Allow SSH for debugging (optional)

Outbound Rules:
  (Keep default: All traffic to 0.0.0.0/0)
```

**Record the Security Group ID**

**Security Flow Verification:**

```
Internet (0.0.0.0/0)
  ↓ (HTTP/HTTPS)
Frontend ALB (weather-frontend-alb-sg)
  ↓ (Port 80)
Frontend EC2 (weather-frontend-sg)
  ↓ (Port 80)
Backend ALB (weather-backend-alb-sg)
  ↓ (Port 3000)
Backend EC2 (weather-backend-sg)
  ↓ (via NAT Gateway)
Internet (External APIs)
```

---

## Phase 4: IAM Roles Setup

Create an IAM role that allows EC2 instances to:
- Pull Docker images from ECR
- Read configuration from Parameter Store
- Send logs to CloudWatch

### 4.1 Create EC2 Instance Role

**AWS Console Steps:**

1. Go to **IAM** → **Roles**
2. Click **"Create role"**

**Step 1: Select trusted entity**

```bash
Trusted entity type: AWS service
Use case: EC2
```

Click **"Next"**

**Step 2: Add permissions**

Search and select these policies:

```bash
1. AmazonEC2ContainerRegistryReadOnly
   (Allows pulling Docker images from ECR)

2. CloudWatchAgentServerPolicy
   (Allows sending logs/metrics to CloudWatch)

3. AmazonSSMManagedInstanceCore
   (Allows Systems Manager Session Manager access)
```

For Parameter Store access, we'll create a custom inline policy:

Click **"Next"** (we'll add inline policy after role creation)

**Step 3: Name and create**

```bash
Role name: weather-ec2-instance-role
Description: IAM role for Weather App EC2 instances with ECR, Parameter Store, and CloudWatch access
```

Click **"Create role"**

### 4.2 Add Parameter Store Inline Policy

1. After role creation, click on **weather-ec2-instance-role**
2. Go to **"Permissions"** tab
3. Click **"Add permissions"** → **"Create inline policy"**
4. Click **"JSON"** tab

Paste this policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath"
      ],
      "Resource": [
        "arn:aws:ssm:*:*:parameter/weather-app/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": [
            "ssm.*.amazonaws.com"
          ]
        }
      }
    }
  ]
}
```

5. Click **"Next"**
6. Name: `ParameterStoreReadPolicy`
7. Click **"Create policy"**

**Record the Role ARN** (e.g., arn:aws:iam::123456789012:role/weather-ec2-instance-role)

**What this role allows:**

- ✅ Pull Docker images from ECR repositories
- ✅ Read configuration from Parameter Store (`/weather-app/*` parameters)
- ✅ Decrypt SecureString parameters
- ✅ Send logs and metrics to CloudWatch
- ✅ Connect via Systems Manager Session Manager (no SSH key needed)

---

## Phase 5: ECR Repository Setup

### 5.1 Create ECR Repositories

**AWS Console Steps:**

1. Go to **Amazon ECR** → **Repositories**
2. Click **"Create repository"**

**Create two repositories:**

**Repository 1: Frontend**

```bash
Visibility settings: Private
Repository name: weather-frontend

Tag immutability: Enable
Scan on push: Enable
```

Click **"Create repository"**

**Record the Repository URI** (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/weather-frontend)

**Repository 2: Backend**

```bash
Visibility settings: Private
Repository name: weather-backend

Tag immutability: Enable
Scan on push: Enable
```

Click **"Create repository"**

**Record the Repository URI**

### 5.2 Update Nginx Configuration Template

Create a dynamic Nginx configuration that uses environment variables:

**Create file: `frontend/nginx.conf.template`**

```nginx
server {
    listen 80;
    server_name localhost;
    
    # Root directory for static files
    root /usr/share/nginx/html;
    index index.html;

    # Serve static files
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy API requests to backend ALB
    location /api/ {
        # Backend ALB DNS will be substituted at runtime
        proxy_pass http://${BACKEND_ALB_DNS};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Error pages
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
```

### 5.3 Update Frontend Dockerfile

Update the frontend Dockerfile to use the template and substitute environment variables at runtime:

**Edit: `frontend/Dockerfile`**

```dockerfile
FROM nginx:alpine

# Copy static files
COPY index.html /usr/share/nginx/html/
COPY style.css /usr/share/nginx/html/
COPY app.js /usr/share/nginx/html/

# Copy nginx config template
COPY nginx.conf.template /etc/nginx/templates/default.conf.template

# The nginx image will automatically substitute environment variables
# in templates and generate the final config at container startup
# No need for additional entrypoint script

EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1
```

**Note:** The official Nginx Docker image automatically processes `.template` files in `/etc/nginx/templates/` and substitutes environment variables at container startup.

### 5.4 Build and Push Docker Images

**Set environment variables:**

```bash
# Set your configuration
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "ECR Registry: $ECR_REGISTRY"
```

**Authenticate Docker to ECR:**

```bash
aws ecr get-login-password --region ${AWS_REGION} | \
    docker login --username AWS --password-stdin ${ECR_REGISTRY}
```

**Build and Push Frontend:**

```bash
cd frontend

# Build
docker build -t weather-frontend:latest .

# Tag
docker tag weather-frontend:latest ${ECR_REGISTRY}/weather-frontend:latest

# Push
docker push ${ECR_REGISTRY}/weather-frontend:latest

cd ..
```

**Build and Push Backend:**

```bash
cd backend

# Build
docker build -t weather-backend:latest .

# Tag
docker tag weather-backend:latest ${ECR_REGISTRY}/weather-backend:latest

# Push
docker push ${ECR_REGISTRY}/weather-backend:latest

cd ..
```

**Verify images are in ECR:**

```bash
aws ecr describe-images --repository-name weather-frontend --region ${AWS_REGION}
aws ecr describe-images --repository-name weather-backend --region ${AWS_REGION}
```

---

## Phase 6: Backend Infrastructure

Deploy the backend tier first, then use its ALB DNS in the frontend configuration.

### 6.1 Create Backend Application Load Balancer

**AWS Console Steps:**

1. Go to **EC2** → **Load Balancers**
2. Click **"Create Load Balancer"** → **"Application Load Balancer"**

**Basic Configuration:**

```bash
Name: weather-backend-alb
Scheme: Internal
IP address type: IPv4
```

**Network mapping:**

```bash
VPC: weather-app-vpc

Availability Zones:
  ☑ us-east-1a → Select: weather-app-subnet-private1-us-east-1a
  ☑ us-east-1b → Select: weather-app-subnet-private2-us-east-1b
```

**Security groups:**

```bash
Remove: default
Add: weather-backend-alb-sg
```

**Listeners and routing:**

```bash
Protocol: HTTP
Port: 80
Default action: Create target group (see below)
```

### 6.2 Create Backend Target Group

Click **"Create target group"** (opens in new tab)

**Specify group details:**

```bash
Target type: Instances
Target group name: weather-backend-tg
Protocol: HTTP
Port: 3000
VPC: weather-app-vpc
Protocol version: HTTP1
```

**Health checks:**

```bash
Health check protocol: HTTP
Health check path: /health

Advanced health check settings:
  Healthy threshold: 2
  Unhealthy threshold: 3
  Timeout: 5 seconds
  Interval: 30 seconds
  Success codes: 200
```

Click **"Next"**

**Register targets:**

Skip this step (instances will be registered by Auto Scaling Group)

Click **"Create target group"**

### 6.3 Complete Backend ALB Creation

Return to the ALB creation tab:

1. Refresh the target group dropdown
2. Select **weather-backend-tg**
3. Click **"Create load balancer"**

**Wait 2-3 minutes** for the ALB to become active.

### 6.4 Record Backend ALB DNS Name

1. Go to **EC2** → **Load Balancers**
2. Select **weather-backend-alb**
3. Copy the **DNS name** (e.g., internal-weather-backend-alb-123456789.us-east-1.elb.amazonaws.com)
4. **Record this in your tracking document**

### 6.5 Update Parameter Store with Backend ALB DNS

**AWS Console Steps:**

1. Go to **AWS Systems Manager** → **Parameter Store**
2. Find parameter: `/weather-app/backend-alb-dns`
3. Click on it, then click **"Edit"**
4. Update **Value** with your Backend ALB DNS name
5. Click **"Save changes"**

**Why update Parameter Store?**

The frontend instances will fetch this value dynamically at startup, so they can proxy API requests to the backend ALB without hardcoding.

### 6.6 Create Backend Launch Template

**AWS Console Steps:**

1. Go to **EC2** → **Launch Templates**
2. Click **"Create launch template"**

**Launch template name and description:**

```bash
Launch template name: weather-backend-lt
Template version description: Backend instances for weather app
```

**Application and OS Images (Amazon Machine Image):**

```bash
Search for: Ubuntu
Select: Ubuntu Server 22.04 LTS (HVM), SSD Volume Type
  - Choose the latest free tier eligible version
  - Architecture: 64-bit (x86)
```

**Instance type:**

```bash
Instance type: t3.micro (or t3.small for production)
```

**Key pair:**

```bash
Key pair: Select an existing key pair or create a new one
(Used for SSH debugging if needed)
```

**Network settings:**

```bash
☐ Don't include in launch template
(Will be configured by Auto Scaling Group)
```

**Expand "Advanced details":**

**IAM instance profile:**

```bash
IAM instance profile: weather-ec2-instance-role
```

**User data:**

Paste the following script (no hardcoded values!):

```bash
#!/bin/bash
set -e

# Log all output
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting backend instance setup..."

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl enable docker
systemctl start docker

# Install AWS CLI v2
apt-get install -y unzip curl
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Get configuration from Parameter Store
echo "Fetching configuration from Parameter Store..."
export AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Fetch parameters
export OPENWEATHER_API_KEY=$(aws ssm get-parameter --name "/weather-app/openweather-api-key" --with-decryption --region ${AWS_REGION} --query "Parameter.Value" --output text)
export PROJECT_NAME=$(aws ssm get-parameter --name "/weather-app/project-name" --region ${AWS_REGION} --query "Parameter.Value" --output text)

echo "Configuration loaded from Parameter Store"
echo "AWS Region: ${AWS_REGION}"
echo "AWS Account: ${AWS_ACCOUNT_ID}"
echo "Project Name: ${PROJECT_NAME}"

# Login to ECR
echo "Logging into ECR..."
aws ecr get-login-password --region ${AWS_REGION} | \
    docker login --username AWS --password-stdin \
    ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Pull backend image
echo "Pulling backend Docker image..."
docker pull ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/weather-backend:latest

# Run backend container
echo "Starting backend container..."
docker run -d \
    --name weather-backend \
    --restart unless-stopped \
    -p 3000:3000 \
    -e PORT=3000 \
    -e NODE_ENV=production \
    -e OPENWEATHER_API_KEY=${OPENWEATHER_API_KEY} \
    ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/weather-backend:latest

# Wait for container to be healthy
echo "Waiting for backend to be healthy..."
sleep 15

# Verify container is running
if docker ps | grep -q weather-backend; then
    echo "Backend container is running successfully"
    docker ps
else
    echo "ERROR: Backend container failed to start"
    docker logs weather-backend
    exit 1
fi

echo "Backend instance setup complete!"
```

Click **"Create launch template"**

**Record the Launch Template ID**

### 6.7 Create Backend Auto Scaling Group

**AWS Console Steps:**

1. Go to **EC2** → **Auto Scaling Groups**
2. Click **"Create Auto Scaling group"**

**Step 1: Choose launch template**

```bash
Auto Scaling group name: weather-backend-asg
Launch template: weather-backend-lt
Version: Latest
```

Click **"Next"**

**Step 2: Choose instance launch options**

```bash
VPC: weather-app-vpc

Availability Zones and subnets:
  ☑ weather-app-subnet-private1-us-east-1a
  ☑ weather-app-subnet-private2-us-east-1b
```

Click **"Next"**

**Step 3: Configure advanced options**

```bash
Load balancing:
  ☑ Attach to an existing load balancer
  
  Choose from your load balancer target groups:
    ☑ weather-backend-tg

Health checks:
  ☑ Turn on Elastic Load Balancing health checks
  Health check grace period: 300 seconds
```

Click **"Next"**

**Step 4: Configure group size and scaling policies**

```bash
Group size:
  Desired capacity: 2
  Minimum capacity: 2
  Maximum capacity: 4

Scaling policies:
  ☑ Target tracking scaling policy
  
  Scaling policy name: backend-cpu-scaling
  Metric type: Average CPU utilization
  Target value: 70
  Instances need: 300 seconds warm up before including in metric
```

Click **"Next"**

**Step 5: Add notifications** (skip)

Click **"Next"**

**Step 6: Add tags**

```bash
Key: Name
Value: weather-backend-instance
Tag new instances: Yes

Key: Project
Value: weather-app
Tag new instances: Yes

Key: Tier
Value: backend
Tag new instances: Yes
```

Click **"Next"**

**Step 7: Review**

Review all settings and click **"Create Auto Scaling group"**

**Wait 5-10 minutes** for instances to launch and become healthy.

### 6.8 Verify Backend Instances

**Check instances are launching:**

1. Go to **EC2** → **Instances**
2. Filter by tag `Tier: backend`
3. Wait for instances to show **Status: Running**
4. Wait for **Status checks** to show **2/2 checks passed**

**Check target health:**

1. Go to **EC2** → **Target Groups**
2. Select **weather-backend-tg**
3. Click **"Targets"** tab
4. Wait for both targets to show **Status: Healthy**

**Troubleshooting if unhealthy:**

```bash
# SSH into a backend instance (use Session Manager or SSH)
# Check Docker container status
sudo docker ps

# Check container logs
sudo docker logs weather-backend

# Check user data log
sudo cat /var/log/user-data.log

# Test health endpoint
curl http://localhost:3000/health
```

---

## Phase 7: Frontend Infrastructure

Now that the backend is running and the Backend ALB DNS is stored in Parameter Store, deploy the frontend tier.

### 7.1 Create Frontend Application Load Balancer

**AWS Console Steps:**

1. Go to **EC2** → **Load Balancers**
2. Click **"Create Load Balancer"** → **"Application Load Balancer"**

**Basic Configuration:**

```bash
Name: weather-frontend-alb
Scheme: Internet-facing
IP address type: IPv4
```

**Network mapping:**

```bash
VPC: weather-app-vpc

Availability Zones:
  ☑ us-east-1a → Select: weather-app-subnet-public1-us-east-1a
  ☑ us-east-1b → Select: weather-app-subnet-public2-us-east-1b
```

**Security groups:**

```bash
Remove: default
Add: weather-frontend-alb-sg
```

**Listeners and routing:**

```bash
Protocol: HTTP
Port: 80
Default action: Create target group (see below)
```

### 7.2 Create Frontend Target Group

Click **"Create target group"** (opens in new tab)

**Specify group details:**

```bash
Target type: Instances
Target group name: weather-frontend-tg
Protocol: HTTP
Port: 80
VPC: weather-app-vpc
Protocol version: HTTP1
```

**Health checks:**

```bash
Health check protocol: HTTP
Health check path: /health

Advanced health check settings:
  Healthy threshold: 2
  Unhealthy threshold: 3
  Timeout: 5 seconds
  Interval: 30 seconds
  Success codes: 200
```

Click **"Next"**

**Register targets:**

Skip this step (instances will be registered by Auto Scaling Group)

Click **"Create target group"**

### 7.3 Complete Frontend ALB Creation

Return to the ALB creation tab:

1. Refresh the target group dropdown
2. Select **weather-frontend-tg**
3. Click **"Create load balancer"**

**Wait 2-3 minutes** for the ALB to become active.

### 7.4 Record Frontend ALB DNS Name

1. Go to **EC2** → **Load Balancers**
2. Select **weather-frontend-alb**
3. Copy the **DNS name** (e.g., weather-frontend-alb-123456789.us-east-1.elb.amazonaws.com)
4. **Record this in your tracking document**

### 7.5 Create Frontend Launch Template

**AWS Console Steps:**

1. Go to **EC2** → **Launch Templates**
2. Click **"Create launch template"**

**Launch template name and description:**

```bash
Launch template name: weather-frontend-lt
Template version description: Frontend instances for weather app
```

**Application and OS Images (Amazon Machine Image):**

```bash
Search for: Ubuntu
Select: Ubuntu Server 22.04 LTS (HVM), SSD Volume Type
  - Choose the latest free tier eligible version
  - Architecture: 64-bit (x86)
```

**Instance type:**

```bash
Instance type: t3.micro (or t3.small for production)
```

**Key pair:**

```bash
Key pair: Select an existing key pair or create a new one
```

**Network settings:**

```bash
☐ Don't include in launch template
(Will be configured by Auto Scaling Group)
```

**Expand "Advanced details":**

**IAM instance profile:**

```bash
IAM instance profile: weather-ec2-instance-role
```

**User data:**

Paste the following script (completely dynamic!):

```bash
#!/bin/bash
set -e

# Log all output
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting frontend instance setup..."

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl enable docker
systemctl start docker

# Install AWS CLI v2
apt-get install -y unzip curl
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Get configuration from Parameter Store and EC2 metadata
echo "Fetching configuration..."
export AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Fetch Backend ALB DNS from Parameter Store
export BACKEND_ALB_DNS=$(aws ssm get-parameter --name "/weather-app/backend-alb-dns" --region ${AWS_REGION} --query "Parameter.Value" --output text)
export PROJECT_NAME=$(aws ssm get-parameter --name "/weather-app/project-name" --region ${AWS_REGION} --query "Parameter.Value" --output text)

echo "Configuration loaded:"
echo "AWS Region: ${AWS_REGION}"
echo "AWS Account: ${AWS_ACCOUNT_ID}"
echo "Project Name: ${PROJECT_NAME}"
echo "Backend ALB DNS: ${BACKEND_ALB_DNS}"

# Validate Backend ALB DNS
if [ "$BACKEND_ALB_DNS" == "placeholder" ] || [ -z "$BACKEND_ALB_DNS" ]; then
    echo "ERROR: Backend ALB DNS not configured in Parameter Store"
    exit 1
fi

# Set backend host and port for nginx (ALB listens on port 80)
export BACKEND_HOST=${BACKEND_ALB_DNS}
export BACKEND_PORT=80

# Login to ECR
echo "Logging into ECR..."
aws ecr get-login-password --region ${AWS_REGION} | \
    docker login --username AWS --password-stdin \
    ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Pull frontend image
echo "Pulling frontend Docker image..."
docker pull ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/weather-frontend:latest

# Run frontend container with backend configuration
echo "Starting frontend container..."
docker run -d \
    --name weather-frontend \
    --restart unless-stopped \
    -p 80:80 \
    -e BACKEND_HOST=${BACKEND_HOST} \
    -e BACKEND_PORT=${BACKEND_PORT} \
    ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/weather-frontend:latest

# Wait for container to be healthy
echo "Waiting for frontend to be healthy..."
sleep 15

# Verify container is running
if docker ps | grep -q weather-frontend; then
    echo "Frontend container is running successfully"
    docker ps
    
    # Test health endpoint
    if curl -f http://localhost/health > /dev/null 2>&1; then
        echo "Health check passed!"
    else
        echo "WARNING: Health check failed"
    fi
else
    echo "ERROR: Frontend container failed to start"
    docker logs weather-frontend
    exit 1
fi

echo "Frontend instance setup complete!"
```

Click **"Create launch template"**

**Record the Launch Template ID**

### 7.6 Create Frontend Auto Scaling Group

**AWS Console Steps:**

1. Go to **EC2** → **Auto Scaling Groups**
2. Click **"Create Auto Scaling group"**

**Step 1: Choose launch template**

```bash
Auto Scaling group name: weather-frontend-asg
Launch template: weather-frontend-lt
Version: Latest
```

Click **"Next"**

**Step 2: Choose instance launch options**

```bash
VPC: weather-app-vpc

Availability Zones and subnets:
  ☑ weather-app-subnet-public1-us-east-1a
  ☑ weather-app-subnet-public2-us-east-1b
```

Click **"Next"**

**Step 3: Configure advanced options**

```bash
Load balancing:
  ☑ Attach to an existing load balancer
  
  Choose from your load balancer target groups:
    ☑ weather-frontend-tg

Health checks:
  ☑ Turn on Elastic Load Balancing health checks
  Health check grace period: 300 seconds
```

Click **"Next"**

**Step 4: Configure group size and scaling policies**

```bash
Group size:
  Desired capacity: 2
  Minimum capacity: 2
  Maximum capacity: 4

Scaling policies:
  ☑ Target tracking scaling policy
  
  Scaling policy name: frontend-cpu-scaling
  Metric type: Average CPU utilization
  Target value: 70
  Instances need: 300 seconds warm up before including in metric
```

Click **"Next"**

**Step 5: Add notifications** (skip)

Click **"Next"**

**Step 6: Add tags**

```bash
Key: Name
Value: weather-frontend-instance
Tag new instances: Yes

Key: Project
Value: weather-app
Tag new instances: Yes

Key: Tier
Value: frontend
Tag new instances: Yes
```

Click **"Next"**

**Step 7: Review**

Review all settings and click **"Create Auto Scaling group"**

**Wait 5-10 minutes** for instances to launch and become healthy.

### 7.7 Verify Frontend Instances

**Check instances are launching:**

1. Go to **EC2** → **Instances**
2. Filter by tag `Tier: frontend`
3. Wait for instances to show **Status: Running**
4. Wait for **Status checks** to show **2/2 checks passed**

**Check target health:**

1. Go to **EC2** → **Target Groups**
2. Select **weather-frontend-tg**
3. Click **"Targets"** tab
4. Wait for both targets to show **Status: Healthy**

---

## Phase 8: Verification

Test the complete application end-to-end.

### 8.1 Test Backend Health (Internal)

Since the backend ALB is internal, test from a frontend instance:

**Option 1: Via Systems Manager Session Manager**

1. Go to **EC2** → **Instances**
2. Select a frontend instance
3. Click **"Connect"** → **"Session Manager"** → **"Connect"**

```bash
# Test backend ALB health
curl http://[BACKEND_ALB_DNS]/health

# Should return: {"status":"healthy",...}
```

**Option 2: Via SSH (if you added SSH rule)**

```bash
ssh -i your-key.pem ubuntu@[FRONTEND_INSTANCE_PUBLIC_IP]
curl http://[BACKEND_ALB_DNS]/health
```

### 8.2 Test Frontend Access (Public)

**Via Browser:**

1. Open your browser
2. Navigate to: `http://[FRONTEND_ALB_DNS]`
3. You should see the weather application interface

**Via curl:**

```bash
# Test frontend health
curl http://[FRONTEND_ALB_DNS]/health

# Should return: healthy

# Test frontend homepage
curl http://[FRONTEND_ALB_DNS]

# Should return HTML content
```

### 8.3 Test Complete Application Flow

**Via Browser:**

1. Open: `http://[FRONTEND_ALB_DNS]`
2. Enter a city name (e.g., "London")
3. Click "Get Weather"
4. Verify weather data is displayed correctly

**Via Browser Developer Tools:**

1. Open browser DevTools (F12)
2. Go to **Network** tab
3. Search for a city
4. Verify API call to `/api/weather?city=London` succeeds
5. Check response data

**Expected flow:**

```
Browser → Frontend ALB → Frontend Instance (Nginx)
  → Backend ALB → Backend Instance (Node.js)
  → OpenWeatherMap API
  → Response back through the chain
```

### 8.4 Verify NAT Gateway High Availability

Test that backend instances in both AZs can reach the internet:

**Test from Backend Instance in AZ 1a:**

```bash
# Connect via Session Manager to a backend instance in us-east-1a
curl -I https://www.google.com
curl -I https://api.openweathermap.org

# Should successfully connect (traffic goes through NAT Gateway 1a)
```

**Test from Backend Instance in AZ 1b:**

```bash
# Connect via Session Manager to a backend instance in us-east-1b
curl -I https://www.google.com
curl -I https://api.openweathermap.org

# Should successfully connect (traffic goes through NAT Gateway 1b)
```

**Verify Route Tables:**

1. Go to **VPC** → **Route Tables**
2. Check **weather-app-rtb-private1-us-east-1a**
   - Route: `0.0.0.0/0` → NAT Gateway 1a ✓
3. Check **weather-app-rtb-private2-us-east-1b**
   - Route: `0.0.0.0/0` → NAT Gateway 1b ✓

### 8.5 Test Auto Scaling (Optional)

**Simulate high CPU load:**

```bash
# SSH into a backend or frontend instance
sudo apt-get install -y stress

# Generate CPU load (70%+ for 5+ minutes)
stress --cpu 4 --timeout 300s

# Watch Auto Scaling Group scale up
# Go to EC2 → Auto Scaling Groups → Activity tab
```

### 8.6 Monitor CloudWatch Metrics

**View key metrics:**

1. Go to **CloudWatch** → **Dashboards**
2. Or check individual metrics:
   - **EC2** → Select instance → **Monitoring** tab
   - **Load Balancers** → Select ALB → **Monitoring** tab

**Key metrics to check:**

- Target Response Time (should be < 1 second)
- Healthy Host Count (should match desired capacity)
- Request Count (should show traffic)
- 4XX/5XX Error Count (should be 0 or very low)

---

## Phase 9: Route 53 Domain Configuration (Optional)

Configure a custom domain name for your application.

### 9.1 Create Hosted Zone (if domain is external)

If your domain is registered outside Route 53:

1. Go to **Route 53** → **Hosted zones**
2. Click **"Create hosted zone"**

```bash
Domain name: yourdomain.com
Type: Public hosted zone
```

3. Click **"Create hosted zone"**
4. Note the **4 NS (nameserver) records**
5. Go to your domain registrar and update nameservers to these 4 AWS nameservers

**Wait for DNS propagation (can take up to 48 hours, usually much faster)**

### 9.2 Create A Record for Application

1. Go to **Route 53** → **Hosted zones**
2. Select your domain
3. Click **"Create record"**

**For root domain (yourdomain.com):**

```bash
Record name: (leave empty)
Record type: A - Routes traffic to an IPv4 address and some AWS resources
Value/Route traffic to:
  ☑ Alias to Application and Classic Load Balancer
  Region: [Your region, e.g., us-east-1]
  Load balancer: weather-frontend-alb
Routing policy: Simple routing
```

Click **"Create records"**

**For www subdomain (www.yourdomain.com):**

```bash
Record name: www
Record type: A
Value/Route traffic to:
  ☑ Alias to Application and Classic Load Balancer
  Region: [Your region]
  Load balancer: weather-frontend-alb
Routing policy: Simple routing
```

Click **"Create records"**

### 9.3 Test Domain

**Wait 5-10 minutes for DNS propagation**, then test:

```bash
# Test DNS resolution
nslookup yourdomain.com
nslookup www.yourdomain.com

# Test via browser
# Open: http://yourdomain.com
# Open: http://www.yourdomain.com
```

---

## Phase 10: SSL/TLS Certificate (Optional but Recommended)

Enable HTTPS for secure communication.

### 10.1 Request Certificate via AWS Certificate Manager

1. Go to **AWS Certificate Manager (ACM)**
2. Ensure you're in the **same region** as your load balancer
3. Click **"Request certificate"**

**Request public certificate:**

```bash
Certificate type: Request a public certificate
```

Click **"Next"**

**Domain names:**

```bash
Fully qualified domain name: yourdomain.com

Add another name to this certificate:
Fully qualified domain name: www.yourdomain.com
```

Click **"Next"**

**Validation method:**

```bash
Validation method: DNS validation - recommended
```

Click **"Request"**

### 10.2 Validate Certificate

**If your domain is in Route 53:**

1. In the certificate details page, click **"Create records in Route 53"**
2. Select both domain names
3. Click **"Create records"**

**If your domain is external:**

1. Note the CNAME record name and value for each domain
2. Add these CNAME records to your domain registrar's DNS settings

**Wait for validation** (can take 5-30 minutes)

### 10.3 Add HTTPS Listener to Frontend ALB

Once certificate shows **Status: Issued**:

1. Go to **EC2** → **Load Balancers**
2. Select **weather-frontend-alb**
3. Click **"Listeners"** tab
4. Click **"Add listener"**

**Add HTTPS listener:**

```bash
Protocol: HTTPS
Port: 443

Default action:
  Forward to: weather-frontend-tg

Security policy: ELBSecurityPolicy-TLS13-1-2-2021-06

Default SSL/TLS certificate:
  From ACM: Select your certificate (yourdomain.com)
```

Click **"Add"**

### 10.4 Redirect HTTP to HTTPS

Make HTTP automatically redirect to HTTPS:

1. In **Listeners** tab, select **HTTP:80** listener
2. Click **"Actions"** → **"Edit listener"**
3. Remove the existing rule
4. Click **"Add action"** → **"Redirect to..."**

```bash
Protocol: HTTPS
Port: 443
Status code: 301 - Permanently moved
```

5. Click **"Save changes"**

### 10.5 Update Security Group

Ensure HTTPS traffic is allowed:

1. Go to **EC2** → **Security Groups**
2. Select **weather-frontend-alb-sg**
3. Verify inbound rule exists:

```bash
Type: HTTPS
Port: 443
Source: 0.0.0.0/0
```

If not, click **"Edit inbound rules"** → **"Add rule"** → **"Save rules"**

### 10.6 Test HTTPS

**Via Browser:**

```bash
# Test HTTPS
https://yourdomain.com
https://www.yourdomain.com

# Verify:
# ✓ Padlock icon appears in browser
# ✓ Certificate is valid
# ✓ HTTP automatically redirects to HTTPS
```

**Via curl:**

```bash
# Test HTTPS
curl -I https://yourdomain.com

# Test HTTP redirect
curl -I http://yourdomain.com
# Should return: 301 Moved Permanently
# Location: https://yourdomain.com/
```

---

## Troubleshooting

### Issue: Backend instances cannot reach internet

**Symptoms:**
- Cannot pull ECR images
- User data script fails
- Container fails to start

**Solution:**

1. **Verify NAT Gateways are Available:**
   - Go to **VPC** → **NAT Gateways**
   - Both should show **Status: Available**

2. **Check Route Tables:**
   - Go to **VPC** → **Route Tables**
   - `weather-app-rtb-private1-us-east-1a`: `0.0.0.0/0` → NAT Gateway 1a
   - `weather-app-rtb-private2-us-east-1b`: `0.0.0.0/0` → NAT Gateway 1b

3. **Verify Subnet Associations:**
   - Private subnet 1a → private route table 1a
   - Private subnet 1b → private route table 1b

4. **Test from Instance:**
   ```bash
   # Via Session Manager
   curl -I https://www.google.com
   ping 8.8.8.8
   ```

### Issue: Parameter Store access denied

**Symptoms:**
- User data script fails to fetch parameters
- Logs show "AccessDenied" errors

**Solution:**

1. **Verify IAM Role:**
   - Go to **IAM** → **Roles** → **weather-ec2-instance-role**
   - Check **ParameterStoreReadPolicy** is attached

2. **Verify Instance Profile:**
   - Go to **EC2** → Select instance → **Security** tab
   - Verify **IAM Role** shows `weather-ec2-instance-role`

3. **Test from Instance:**
   ```bash
   # Via Session Manager
   aws ssm get-parameter --name "/weather-app/project-name" --region us-east-1
   ```

### Issue: Frontend cannot reach backend

**Symptoms:**
- Frontend loads but shows errors when searching
- API calls fail with 504 timeout or 502 bad gateway

**Solution:**

1. **Verify Backend ALB DNS in Parameter Store:**
   ```bash
   aws ssm get-parameter --name "/weather-app/backend-alb-dns" --region us-east-1
   # Should NOT be "placeholder"
   ```

2. **Check Security Groups:**
   - `weather-backend-alb-sg` inbound: Port 80 from `weather-frontend-sg` ✓
   - `weather-frontend-sg` outbound: All traffic ✓

3. **Test from Frontend Instance:**
   ```bash
   # Via Session Manager
   BACKEND_DNS=$(aws ssm get-parameter --name "/weather-app/backend-alb-dns" --region us-east-1 --query "Parameter.Value" --output text)
   curl http://${BACKEND_DNS}/health
   ```

4. **Check Backend Target Health:**
   - Go to **EC2** → **Target Groups** → **weather-backend-tg**
   - Both targets should show **Status: Healthy**

### Issue: Instances failing health checks

**Symptoms:**
- Targets show "Unhealthy" status
- Instances keep getting replaced

**Solution:**

1. **Check Docker Container:**
   ```bash
   # SSH or Session Manager into instance
   sudo docker ps
   sudo docker logs weather-backend  # or weather-frontend
   ```

2. **Check User Data Logs:**
   ```bash
   sudo cat /var/log/user-data.log
   ```

3. **Test Health Endpoint Locally:**
   ```bash
   # Backend
   curl http://localhost:3000/health
   
   # Frontend
   curl http://localhost/health
   ```

4. **Verify Health Check Path:**
   - Go to **EC2** → **Target Groups**
   - Check **Health check path** is correct (`/health`)

5. **Check Security Groups:**
   - Target group port is allowed from ALB security group

### Issue: One Availability Zone not working

**Symptoms:**
- Some backend instances can't reach internet
- Reduced capacity but application still works

**Solution:**

1. **Check NAT Gateway for that AZ:**
   - Go to **VPC** → **NAT Gateways**
   - Find NAT Gateway for failing AZ
   - Verify **Status: Available**

2. **Check Route Table:**
   - Verify private route table for that AZ routes to correct NAT Gateway

3. **Check Subnet Association:**
   - Verify correct private subnet is associated with correct route table

**This validates HA setup - if one AZ fails, the other continues!**

### Issue: High costs from NAT Gateways

**Understanding:**
- 2 NAT Gateways cost ~$64/month
- Plus data transfer charges (~$0.045/GB)

**Solutions:**

1. **For Development:** Use 1 NAT Gateway temporarily
   - Less HA but reduces cost by 50%

2. **Use VPC Endpoints:**
   - Add S3 endpoint (free)
   - Add ECR endpoints (~$7/month but saves NAT data transfer)

3. **Schedule Downtime:**
   - Delete NAT Gateways when not testing
   - Recreate when needed

**WARNING:** Deleting NAT Gateways breaks backend internet access!

### Issue: Cannot pull from ECR

**Symptoms:**
- Docker pull fails
- "repository does not exist" or "access denied" errors

**Solution:**

1. **Verify IAM Role Permissions:**
   - Check `AmazonEC2ContainerRegistryReadOnly` policy is attached

2. **Verify ECR Repository Exists:**
   ```bash
   aws ecr describe-repositories --region us-east-1
   ```

3. **Test ECR Login:**
   ```bash
   aws ecr get-login-password --region us-east-1 | \
       docker login --username AWS --password-stdin \
       ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com
   ```

4. **Check Internet Connectivity:**
   - Backend instances need NAT Gateway for ECR access
   - Verify NAT Gateway is working (see above)

---

## Updating the Application

All updates are handled dynamically - no need to update Parameter Store unless changing configuration values.

### Update Backend Code

```bash
# Make changes to backend code
cd backend

# Rebuild image
docker build -t weather-backend:latest .

# Tag for ECR
docker tag weather-backend:latest ${ECR_REGISTRY}/weather-backend:latest

# Push to ECR
docker push ${ECR_REGISTRY}/weather-backend:latest

# Update running instances (Option 1: Terminate instances - ASG will launch new ones)
# Go to EC2 → Auto Scaling Groups → weather-backend-asg
# Activity → Instance refresh → Start

# Or (Option 2: Terminate instances manually)
# Go to EC2 → Instances → Select backend instances → Instance state → Terminate
# ASG will automatically launch new instances with updated image

cd ..
```

### Update Frontend Code

```bash
# Make changes to frontend code
cd frontend

# Rebuild image
docker build -t weather-frontend:latest .

# Tag for ECR
docker tag weather-frontend:latest ${ECR_REGISTRY}/weather-frontend:latest

# Push to ECR
docker push ${ECR_REGISTRY}/weather-frontend:latest

# Update running instances
# Go to EC2 → Auto Scaling Groups → weather-frontend-asg
# Activity → Instance refresh → Start

cd ..
```

### Update Configuration (Parameter Store)

```bash
# Update OpenWeatherMap API key
aws ssm put-parameter \
    --name "/weather-app/openweather-api-key" \
    --value "new_api_key_here" \
    --type "SecureString" \
    --overwrite \
    --region us-east-1

# Update Backend ALB DNS (if recreated)
aws ssm put-parameter \
    --name "/weather-app/backend-alb-dns" \
    --value "new-backend-alb-dns.elb.amazonaws.com" \
    --type "String" \
    --overwrite \
    --region us-east-1

# Restart instances to pick up new configuration
# Terminate instances in ASG - new ones will fetch updated values
```

**No rebuilding Docker images needed when updating Parameter Store values!**

---

## Monitoring and Maintenance

### CloudWatch Metrics

**Key metrics to monitor:**

1. **EC2 Metrics:**
   - CPU Utilization
   - Network In/Out
   - Status Check Failed

2. **ALB Metrics:**
   - Target Response Time
   - Healthy Host Count
   - Request Count
   - HTTP 4XX/5XX Count

3. **Auto Scaling Metrics:**
   - Group Desired Capacity
   - Group In Service Instances
   - Group Total Instances

**View metrics:**
- Go to **CloudWatch** → **Dashboards** (create custom dashboard)
- Or **EC2** → Select resource → **Monitoring** tab

### CloudWatch Alarms

**Recommended alarms:**

1. **Unhealthy Targets:**
   ```bash
   Metric: UnHealthyHostCount
   Threshold: >= 1
   Action: Send SNS notification
   ```

2. **High Response Time:**
   ```bash
   Metric: TargetResponseTime
   Threshold: > 1 second
   Action: Send SNS notification
   ```

3. **High CPU:**
   ```bash
   Metric: CPUUtilization
   Threshold: > 80% for 2 consecutive periods
   Action: Send SNS notification
   ```

4. **5XX Errors:**
   ```bash
   Metric: HTTPCode_Target_5XX_Count
   Threshold: > 10 in 5 minutes
   Action: Send SNS notification
   ```

### View Logs

**Backend Logs:**
```bash
# Via Session Manager
sudo docker logs weather-backend

# Follow logs in real-time
sudo docker logs -f weather-backend
```

**Frontend Logs:**
```bash
# Via Session Manager
sudo docker logs weather-frontend

# Follow logs
sudo docker logs -f weather-frontend
```

**User Data Logs:**
```bash
# Check instance startup logs
sudo cat /var/log/user-data.log

# Check cloud-init logs
sudo cat /var/log/cloud-init-output.log
```

**CloudWatch Logs (Optional - requires agent configuration):**

To send logs to CloudWatch, add this to user data scripts:

```bash
# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb

# Configure and start agent (requires config file)
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
```

---

## Cost Optimization

### Estimated Monthly Costs (us-east-1)

**Minimum deployment (2 instances each tier):**

```
Component                          Cost/Month
───────────────────────────────────────────────
EC2 (4 × t3.micro)                 ~$30.00
NAT Gateways (2)                   ~$64.00
Application Load Balancers (2)     ~$32.00
Data Transfer (estimate)           ~$10.00
EBS Storage (4 × 8GB)              ~$3.00
───────────────────────────────────────────────
Total                              ~$139.00/month
```

**Most expensive components:**
1. NAT Gateways (46% of cost)
2. EC2 Instances (22%)
3. Load Balancers (23%)

### Cost Reduction Strategies

**1. Use Smaller Instance Types:**
```bash
Development: t3.micro ($0.0104/hour)
Production: t3.small ($0.0208/hour) or t3.medium ($0.0416/hour)
```

**2. Reduce NAT Gateway Costs:**

**Option A: Use 1 NAT Gateway (Development only)**
- Saves ~$32/month (50% reduction)
- Less High Availability
- Not recommended for production

**Option B: Use VPC Endpoints**
```bash
# Add S3 Gateway Endpoint (Free!)
# Reduces data transfer through NAT Gateway for S3 access

# Add ECR Interface Endpoints (~$7/month)
# Reduces NAT Gateway data transfer charges
# Endpoints: com.amazonaws.region.ecr.api, com.amazonaws.region.ecr.dkr
```

**3. Schedule Auto Scaling:**
```bash
# Scale down during off-hours
# Set minimum capacity to 1 during nights/weekends
# Use AWS Instance Scheduler (free tool)
```

**4. Use Reserved Instances or Savings Plans:**
```bash
# For long-term workloads (1-3 years)
# Can save up to 72% on EC2 costs
# Calculate savings at: https://aws.amazon.com/savingsplans/pricing/
```

**5. Enable Auto Scaling:**
```bash
# Start with min capacity of 1 per tier (development)
# Let it scale up only when needed
# Reduces idle instance costs
```

**6. Clean Up Unused Resources:**
```bash
# Delete old AMIs and snapshots
# Remove unused Elastic IPs
# Clean up old ECR images (keep latest 3)
```

**7. Monitor with AWS Cost Explorer:**
```bash
# Track daily spending
# Set up billing alerts
# Identify cost anomalies early
```

---

## Security Best Practices

### 1. Use HTTPS (SSL/TLS)

✅ **Always enable HTTPS in production** (Phase 10)
- Protects data in transit
- Builds user trust
- Required for production applications

### 2. Restrict SSH Access

```bash
# Option A: Use Systems Manager Session Manager (Recommended)
- No SSH keys needed
- Access logs in CloudTrail
- No need for port 22 open

# Option B: Restrict SSH to specific IPs
Security Group rule:
  Type: SSH
  Port: 22
  Source: Your specific IP address (not 0.0.0.0/0)
```

### 3. Secure API Keys

✅ **Use Parameter Store SecureString** (already implemented)
- Never hardcode API keys
- Use encryption at rest
- Rotate keys periodically

```bash
# Rotate OpenWeatherMap API key
aws ssm put-parameter \
    --name "/weather-app/openweather-api-key" \
    --value "new_key_here" \
    --type "SecureString" \
    --overwrite
```

### 4. Enable VPC Flow Logs

**Monitor network traffic:**

1. Go to **VPC** → **Your VPCs**
2. Select **weather-app-vpc**
3. Click **"Flow logs"** tab → **"Create flow log"**

```bash
Filter: All
Destination: Send to CloudWatch Logs
Log group: /aws/vpc/weather-app-flow-logs
IAM role: Create new role
```

### 5. Enable AWS CloudTrail

**Audit all API calls:**

1. Go to **CloudTrail** → **Trails**
2. Click **"Create trail"**

```bash
Trail name: weather-app-trail
Storage location: Create new S3 bucket
Log file validation: Enabled
```

### 6. Regular Security Updates

**Keep instances updated:**

```bash
# Add to user data scripts (or run periodically)
sudo apt-get update
sudo apt-get upgrade -y

# Or use AWS Systems Manager Patch Manager for automated patching
```

### 7. Use AWS WAF (Web Application Firewall)

**Protect against common web exploits:**

1. Go to **AWS WAF** → **Web ACLs**
2. Create Web ACL with managed rule sets:
   - AWS Managed Rules - Core rule set
   - AWS Managed Rules - Known bad inputs
   - Rate-based rule (e.g., 2000 requests per 5 minutes)

3. Associate with Frontend ALB

**Cost:** ~$5-10/month base + per-request charges

### 8. Implement Secrets Rotation

**For sensitive data:**

```bash
# Use AWS Secrets Manager instead of Parameter Store
# Automatic rotation for RDS, DocumentDB, etc.
# Costs ~$0.40/secret/month + API calls
```

### 9. Network Segmentation

✅ **Already implemented:**
- Frontend in public subnets
- Backend in private subnets
- Backend not accessible from internet
- Security groups restrict traffic flow

### 10. Enable EBS Encryption

**Encrypt data at rest:**

1. Go to **EC2** → **Account Attributes** → **EBS encryption**
2. Click **"Manage"**
3. Enable **"Always encrypt new EBS volumes"**

### 11. Implement Backup Strategy

**Backup critical data:**

```bash
# Use AWS Backup for automated backups
1. Go to AWS Backup
2. Create backup plan
3. Assign resources (EC2 instances, EBS volumes)
4. Set retention period (e.g., 7 days)
```

---

## Cleanup and Resource Deletion

To avoid ongoing charges, delete resources in this order:

### Step-by-Step Deletion

**1. Set Auto Scaling Group Capacity to 0:**

```bash
# Frontend ASG
1. Go to EC2 → Auto Scaling Groups
2. Select: weather-frontend-asg
3. Edit → Desired capacity: 0, Min: 0, Max: 0
4. Save

# Backend ASG
5. Select: weather-backend-asg
6. Edit → Desired capacity: 0, Min: 0, Max: 0
7. Save

# Wait for all instances to terminate
```

**2. Delete Auto Scaling Groups:**

```bash
1. Select: weather-frontend-asg
2. Actions → Delete
3. Confirm deletion

4. Select: weather-backend-asg
5. Actions → Delete
6. Confirm deletion
```

**3. Delete Load Balancers:**

```bash
1. Go to EC2 → Load Balancers
2. Select: weather-frontend-alb
3. Actions → Delete load balancer → Confirm

4. Select: weather-backend-alb
5. Actions → Delete load balancer → Confirm
```

**4. Delete Target Groups:**

```bash
1. Go to EC2 → Target Groups
2. Select: weather-frontend-tg
3. Actions → Delete → Confirm

4. Select: weather-backend-tg
5. Actions → Delete → Confirm
```

**5. Delete Launch Templates:**

```bash
1. Go to EC2 → Launch Templates
2. Select: weather-frontend-lt
3. Actions → Delete template → Confirm

4. Select: weather-backend-lt
5. Actions → Delete template → Confirm
```

**6. Terminate Any Remaining EC2 Instances:**

```bash
1. Go to EC2 → Instances
2. Filter by tag: Project = weather-app
3. Select all instances
4. Instance state → Terminate instance → Confirm
```

**7. Delete NAT Gateways (CRITICAL - Most Expensive):**

```bash
1. Go to VPC → NAT Gateways
2. Select: weather-app-nat-public1-us-east-1a
3. Actions → Delete NAT gateway → Confirm

4. Select: weather-app-nat-public2-us-east-1b
5. Actions → Delete NAT gateway → Confirm

# Wait 5-10 minutes for deletion to complete
```

**8. Release Elastic IPs:**

```bash
1. Go to VPC → Elastic IPs
2. Find the 2 EIPs (were used by NAT Gateways)
3. Select each → Actions → Release Elastic IP address → Confirm
```

**9. Delete VPC and All Associated Resources:**

**Option A: Using VPC Deletion Wizard (Recommended)**

```bash
1. Go to VPC → Your VPCs
2. Select: weather-app-vpc
3. Actions → Delete VPC

AWS will show all resources to be deleted:
  - Internet Gateway
  - Subnets (4)
  - Route Tables (3 custom)
  - Security Groups (4 custom)
  - Network ACLs
  
4. Check: Delete associated resources
5. Type "delete" to confirm
6. Click Delete

# This deletes everything in one go!
```

**Option B: Manual Deletion (if VPC wizard fails)**

```bash
# Delete Internet Gateway
1. Go to VPC → Internet Gateways
2. Select: weather-app-igw
3. Actions → Detach from VPC → Confirm
4. Actions → Delete internet gateway → Confirm

# Delete Subnets
5. Go to VPC → Subnets
6. Select all 4 weather-app subnets
7. Actions → Delete subnet → Confirm

# Delete Route Tables
8. Go to VPC → Route Tables
9. Select 3 custom route tables (not the main one)
10. Actions → Delete route table → Confirm

# Delete Security Groups
11. Go to EC2 → Security Groups
12. Select all 4 weather-app security groups
13. Actions → Delete security groups → Confirm

# Delete VPC
14. Go to VPC → Your VPCs
15. Select: weather-app-vpc
16. Actions → Delete VPC → Confirm
```

**10. Delete ECR Repositories:**

```bash
1. Go to Amazon ECR → Repositories
2. Select: weather-frontend
3. Delete (will delete all images too) → Confirm

4. Select: weather-backend
5. Delete → Confirm
```

**11. Delete IAM Role:**

```bash
1. Go to IAM → Roles
2. Search: weather-ec2-instance-role
3. Select → Delete → Confirm
```

**12. Delete Parameter Store Parameters:**

```bash
1. Go to AWS Systems Manager → Parameter Store
2. Select all /weather-app/* parameters
3. Delete → Confirm

# Or via CLI
aws ssm delete-parameters \
    --names \
    "/weather-app/openweather-api-key" \
    "/weather-app/aws-region" \
    "/weather-app/project-name" \
    "/weather-app/backend-alb-dns"
```

**13. Delete Route 53 Records (if created):**

```bash
1. Go to Route 53 → Hosted zones
2. Select your domain
3. Delete A records for:
   - yourdomain.com (pointing to ALB)
   - www.yourdomain.com (pointing to ALB)
   
# Keep hosted zone if you're still using the domain
# Delete hosted zone only if you're done with it
```

**14. Delete ACM Certificates (if no longer needed):**

```bash
1. Go to AWS Certificate Manager
2. Select your certificate
3. Actions → Delete → Confirm

# Note: Can only delete if not in use by any ALB
```

**15. Delete CloudWatch Log Groups (optional):**

```bash
1. Go to CloudWatch → Log groups
2. Delete any log groups created:
   - /aws/vpc/weather-app-flow-logs
   - /aws/ec2/weather-app-*
3. Select → Actions → Delete log group(s)
```

### Verification After Cleanup

**Verify no resources remain:**

```bash
# Check EC2
1. EC2 → Instances: 0 running instances
2. EC2 → Load Balancers: No weather-app ALBs
3. EC2 → Security Groups: No weather-app SGs (default SG remains)

# Check VPC
4. VPC → Your VPCs: No weather-app-vpc
5. VPC → NAT Gateways: 0 NAT Gateways
6. VPC → Elastic IPs: 0 unattached EIPs (or only ones you use elsewhere)

# Check ECR
7. ECR → Repositories: No weather-frontend or weather-backend

# Check Billing
8. Wait 24 hours
9. Check AWS Billing Dashboard for charges
10. Most charges should stop immediately
11. Some small charges may appear for data storage/transfer
```

### Common Cleanup Mistakes

❌ **Forgetting to delete NAT Gateways** → Continue paying ~$64/month
❌ **Not releasing Elastic IPs** → Charged $0.005/hour per unattached IP
❌ **Leaving Auto Scaling Groups active** → Continue launching instances
❌ **Not checking all regions** → Resources in wrong region remain active
❌ **Deleting VPC before NAT Gateways** → VPC deletion fails

### Cost Savings After Cleanup

**Immediate savings:**
- EC2 instances: ~$30/month saved
- NAT Gateways: ~$64/month saved
- Load Balancers: ~$32/month saved

**Total savings: ~$139/month**

### Alternative: Pause Instead of Delete

**For temporary pause (save ~78% of costs):**

```bash
1. Set ASG desired capacity to 0 (keeps definitions)
2. Delete NAT Gateways (biggest cost)
3. Release Elastic IPs
4. Keep everything else (VPC, security groups, launch templates, ECR images)

Cost during pause: ~$32/month (just ALBs)
Savings: ~$107/month

To resume:
1. Recreate NAT Gateways
2. Set ASG desired capacity back to 2
3. Wait for instances to launch
```

---

## Additional Resources

### AWS Documentation

- [AWS VPC User Guide](https://docs.aws.amazon.com/vpc/)
- [AWS EC2 User Guide](https://docs.aws.amazon.com/ec2/)
- [AWS Auto Scaling Documentation](https://docs.aws.amazon.com/autoscaling/)
- [AWS Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/)
- [Amazon ECR User Guide](https://docs.aws.amazon.com/ecr/)
- [AWS Systems Manager Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)

### API Documentation

- [OpenWeatherMap API Documentation](https://openweathermap.org/api)
- [OpenWeatherMap Current Weather API](https://openweathermap.org/current)

### Docker Resources

- [Docker Documentation](https://docs.docker.com/)
- [Nginx Docker Official Image](https://hub.docker.com/_/nginx)
- [Node.js Docker Official Image](https://hub.docker.com/_/node)

### AWS Console

- [AWS Management Console](https://console.aws.amazon.com/)
- [AWS Free Tier](https://aws.amazon.com/free/)
- [AWS Pricing Calculator](https://calculator.aws/)

### Helpful Tools

- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/)
- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [AWS CloudFormation (for future automation)](https://aws.amazon.com/cloudformation/)

---

## Summary

This guide deployed a production-ready weather application on AWS with:

✅ **Dynamic Configuration** - No hardcoded values, everything in Parameter Store
✅ **High Availability** - 2 AZs with 2 NAT Gateways for redundancy
✅ **Security** - Private backend, security groups, encrypted secrets
✅ **Scalability** - Auto Scaling Groups with target tracking
✅ **Load Balancing** - Separate ALBs for frontend and backend tiers
✅ **Easy Updates** - Update Parameter Store or push new images, no config changes needed

**Key Improvements in This Guide:**

1. **No Hardcoding:** All configuration values dynamically retrieved from Parameter Store or EC2 metadata
2. **Logical Order:** Backend deployed first (generates DNS), then frontend uses it
3. **Single Source of Truth:** Parameter Store centralizes all configuration
4. **Easy Updates:** Change values in Parameter Store, restart instances
5. **Better Security:** API keys encrypted as SecureString
6. **Simpler Maintenance:** Update images without touching configuration

**What You Built:**

```
Internet → Route 53 → Frontend ALB → Frontend ASG (Nginx) 
  → Backend ALB → Backend ASG (Node.js) → OpenWeatherMap API
  
All configuration dynamically loaded at runtime!
```

**Next Steps:**

1. ✅ Enable HTTPS with ACM certificate (Phase 10)
2. ✅ Add CloudWatch alarms for monitoring
3. ✅ Implement AWS WAF for additional security
4. ✅ Set up automated backups with AWS Backup
5. ✅ Consider CloudFormation/Terraform for infrastructure as code

---

## License

MIT License - Feel free to use this project for learning and production purposes.

---

## Support

If you encounter issues:

1. Check the **Troubleshooting** section
2. Review CloudWatch logs and metrics
3. Test individual components (backend health, frontend health, connectivity)
4. Verify security group rules
5. Check Parameter Store values are correct
6. Review user data logs: `sudo cat /var/log/user-data.log`

For AWS-specific issues, consult AWS Support or AWS forums.

**Happy Deploying! 🚀**