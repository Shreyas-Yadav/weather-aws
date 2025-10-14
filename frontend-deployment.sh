#!/bin/bash
set -e

echo "=================================="
echo "Frontend Instance Setup Starting"
echo "Timestamp: $(date)"
echo "=================================="

# ============================================
# STEP 1: Update System Packages
# ============================================
echo ""
echo "[1/11] Updating system packages..."
apt-get update
apt-get upgrade -y
echo "✓ System packages updated"

# ============================================
# STEP 2: Install Docker
# ============================================
echo ""
echo "[2/11] Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    systemctl enable docker
    systemctl start docker
    rm get-docker.sh
    echo "✓ Docker installed successfully"
else
    echo "✓ Docker already installed"
fi

# Verify Docker installation
docker --version

# ============================================
# STEP 3: Install AWS CLI v2
# ============================================
echo ""
echo "[3/11] Installing AWS CLI v2..."
if ! command -v aws &> /dev/null; then
    apt-get install -y unzip curl
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
    echo "✓ AWS CLI installed successfully"
else
    echo "✓ AWS CLI already installed"
fi

# Verify AWS CLI installation
aws --version

# ============================================
# STEP 4: Get AWS Account ID
# ============================================
echo ""
echo "[4/11] Fetching AWS account ID..."
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "AWS Account ID: ${AWS_ACCOUNT_ID}"
echo "✓ AWS account ID retrieved"

# ============================================
# STEP 5: Fetch Configuration from Parameter Store
# ============================================
echo ""
echo "[5/11] Fetching configuration from Parameter Store..."

# Fetch AWS Region from Parameter Store
export AWS_REGION=$(aws ssm get-parameter \
    --name "/weather-app/aws-region" \
    --query "Parameter.Value" \
    --output text)

if [ -z "$AWS_REGION" ] || [ "$AWS_REGION" == "None" ]; then
    echo "✗ ERROR: Failed to retrieve AWS region from Parameter Store"
    echo "Please ensure parameter '/weather-app/aws-region' exists"
    exit 1
fi
echo "✓ AWS Region retrieved: ${AWS_REGION}"

# Fetch Backend Host (Private IP of backend instance)
export BACKEND_HOST=$(aws ssm get-parameter \
    --name "/weather-app/backend-host" \
    --region ${AWS_REGION} \
    --query "Parameter.Value" \
    --output text)

if [ -z "$BACKEND_HOST" ] || [ "$BACKEND_HOST" == "None" ]; then
    echo "✗ ERROR: Failed to retrieve backend host from Parameter Store"
    echo "Please ensure parameter '/weather-app/backend-host' exists"
    exit 1
fi
echo "✓ Backend Host retrieved: ${BACKEND_HOST}"

# Fetch Backend Port
export BACKEND_PORT=$(aws ssm get-parameter \
    --name "/weather-app/backend-port" \
    --region ${AWS_REGION} \
    --query "Parameter.Value" \
    --output text)

if [ -z "$BACKEND_PORT" ] || [ "$BACKEND_PORT" == "None" ]; then
    echo "✗ ERROR: Failed to retrieve backend port from Parameter Store"
    echo "Please ensure parameter '/weather-app/backend-port' exists"
    exit 1
fi
echo "✓ Backend Port retrieved: ${BACKEND_PORT}"

# Fetch ECR Registry Frontend URI
export ECR_REGISTRY_FRONTEND=$(aws ssm get-parameter \
    --name "/weather-app/ecr-registry-frontend" \
    --region ${AWS_REGION} \
    --query "Parameter.Value" \
    --output text)

if [ -z "$ECR_REGISTRY_FRONTEND" ] || [ "$ECR_REGISTRY_FRONTEND" == "None" ]; then
    echo "✗ ERROR: Failed to retrieve ECR registry frontend URI from Parameter Store"
    echo "Please ensure parameter '/weather-app/ecr-registry-frontend' exists"
    exit 1
fi
echo "✓ ECR Registry Frontend retrieved: ${ECR_REGISTRY_FRONTEND}"
echo "✓ Configuration loaded from Parameter Store"

# ============================================
# STEP 6: Login to ECR
# ============================================
echo ""
echo "[6/11] Authenticating with ECR..."
aws ecr get-login-password --region ${AWS_REGION} | \
    docker login --username AWS --password-stdin ${ECR_REGISTRY_FRONTEND}

if [ $? -eq 0 ]; then
    echo "✓ ECR authentication successful"
else
    echo "✗ ERROR: ECR authentication failed"
    echo "Please ensure:"
    echo "  1. IAM role has 'AmazonEC2ContainerRegistryReadOnly' policy"
    echo "  2. ECR repository exists"
    echo "  3. Instance can reach ECR (check NAT Gateway if in private subnet)"
    exit 1
fi

# ============================================
# STEP 7: Pull Docker Image from ECR
# ============================================
echo ""
echo "[7/11] Pulling frontend Docker image from ECR..."
docker pull ${ECR_REGISTRY_FRONTEND}

if [ $? -eq 0 ]; then
    echo "✓ Docker image pulled successfully"
    docker images | grep weather-frontend
else
    echo "✗ ERROR: Failed to pull Docker image"
    echo "Please ensure:"
    echo "  1. ECR repository 'weather-frontend' exists"
    echo "  2. Image 'weather-frontend:latest' is pushed to ECR"
    echo "  3. Instance has internet connectivity (NAT Gateway for private subnets)"
    exit 1
fi

# ============================================
# STEP 8: Stop and Remove Old Container (if exists)
# ============================================
echo ""
echo "[8/11] Cleaning up old containers..."
if docker ps -a | grep -q weather-frontend; then
    echo "Found existing container, removing..."
    docker stop weather-frontend 2>/dev/null || true
    docker rm weather-frontend 2>/dev/null || true
    echo "✓ Old container removed"
else
    echo "✓ No old container found"
fi

# ============================================
# STEP 9: Run Frontend Container
# ============================================
echo ""
echo "[9/11] Starting frontend container..."
docker run -d \
    --name weather-frontend \
    --restart unless-stopped \
    -p 80:80 \
    -e BACKEND_HOST=${BACKEND_HOST} \
    -e BACKEND_PORT=${BACKEND_PORT} \
    ${ECR_REGISTRY_FRONTEND}

if [ $? -eq 0 ]; then
    echo "✓ Frontend container started"
else
    echo "✗ ERROR: Failed to start frontend container"
    docker logs weather-frontend 2>&1
    exit 1
fi

# Wait for container to initialize
echo "Waiting for container to initialize..."
sleep 10

# ============================================
# STEP 10: Verify Deployment
# ============================================
echo ""
echo "[10/11] Verifying deployment..."

# Check if container is running
if docker ps | grep -q weather-frontend; then
    echo "✓ Container is running"
    echo ""
    echo "Container Details:"
    docker ps | grep weather-frontend
    echo ""

    # Test health endpoint
    echo "Testing health endpoint..."
    HEALTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health)

    if [ "$HEALTH_CHECK" == "200" ]; then
        echo "✓ Health check passed (HTTP $HEALTH_CHECK)"
        echo ""
        echo "Health Response:"
        curl -s http://localhost/health
    else
        echo "✗ Health check failed (HTTP $HEALTH_CHECK)"
        echo ""
        echo "Container logs:"
        docker logs weather-frontend
        exit 1
    fi

    # Test if frontend is serving HTML
    echo ""
    echo "Testing frontend page..."
    FRONTEND_CHECK=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/)

    if [ "$FRONTEND_CHECK" == "200" ]; then
        echo "✓ Frontend page accessible (HTTP $FRONTEND_CHECK)"
    else
        echo "⚠ Frontend page returned HTTP $FRONTEND_CHECK"
    fi
else
    echo "✗ Container is not running"
    echo ""
    echo "Container logs:"
    docker logs weather-frontend 2>&1
    exit 1
fi

# ============================================
# STEP 11: Display Nginx Configuration
# ============================================
echo ""
echo "[11/11] Verifying Nginx configuration..."
echo "Backend configuration:"
echo "  BACKEND_HOST: ${BACKEND_HOST}"
echo "  BACKEND_PORT: ${BACKEND_PORT}"
echo ""
echo "Checking generated nginx config:"
docker exec weather-frontend cat /etc/nginx/conf.d/default.conf | grep -A 5 "location /api/"

# ============================================
# DEPLOYMENT COMPLETE
# ============================================
echo ""
echo "=================================="
echo "✓ Frontend Deployment Complete!"
echo "=================================="
echo "Container Name: weather-frontend"
echo "Port: 80"
echo "Health Endpoint: http://localhost/health"
echo "Frontend URL: http://localhost/"
echo "Backend Proxy: http://${BACKEND_HOST}:${BACKEND_PORT}"
echo "Timestamp: $(date)"
echo "=================================="

# Display final status
echo ""
echo "Final Status:"
docker ps
echo ""
echo "To view logs: sudo docker logs -f weather-frontend"
echo "To check status: sudo docker ps"
echo "To restart: sudo docker restart weather-frontend"
echo "To test API proxy: curl http://localhost/api/weather?city=London"
