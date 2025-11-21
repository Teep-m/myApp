#!/bin/bash

# GCP Deployment Script for MyApp
# This script deploys the application to Google Compute Engine

set -e

echo "=================================="
echo "  MyApp - GCP Deployment Script"
echo "=================================="
echo ""

# Configuration
PROJECT_ID=${GCP_PROJECT_ID:-""}
INSTANCE_NAME="myapp-vm"
ZONE="asia-northeast1-a"
MACHINE_TYPE="e2-medium"
REGION="asia-northeast1"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI is not installed."
    echo "   Visit: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if project ID is set
if [ -z "$PROJECT_ID" ]; then
    echo "Please enter your GCP Project ID:"
    read -r PROJECT_ID
fi

echo "Using GCP Project: $PROJECT_ID"
gcloud config set project "$PROJECT_ID"

# Create VM instance
echo ""
echo "📦 Creating Compute Engine instance..."
gcloud compute instances create "$INSTANCE_NAME" \
    --zone="$ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=50GB \
    --tags=http-server,https-server \
    --metadata=startup-script='#!/bin/bash
        # Install Docker
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        
        # Install Docker Compose
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        
        # Add ubuntu user to docker group
        usermod -aG docker ubuntu
    ' || echo "Instance might already exist"

# Wait for instance to be ready
echo "⏳ Waiting for instance to be ready..."
sleep 30

# Configure firewall rules
echo ""
echo "🔥 Configuring firewall rules..."
gcloud compute firewall-rules create allow-myapp-http \
    --allow=tcp:3000,tcp:8080 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=http-server \
    --description="Allow HTTP traffic to MyApp" || echo "Firewall rule might already exist"

# Get instance external IP
EXTERNAL_IP=$(gcloud compute instances describe "$INSTANCE_NAME" \
    --zone="$ZONE" \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo ""
echo "✅ Instance created with IP: $EXTERNAL_IP"

# SSH and deploy
echo ""
echo "🚀 Deploying application to instance..."
echo "   This will take a few minutes..."

# Copy files to instance
echo "📤 Copying application files..."
gcloud compute scp --recurse --zone="$ZONE" \
    $(pwd) "${INSTANCE_NAME}:~/myapp" \
    --exclude=".git" \
    --exclude="node_modules" \
    --exclude="target" \
    --exclude="zig-out" \
    --exclude="zig-cache"

# Deploy on instance
gcloud compute ssh "$INSTANCE_NAME" --zone="$ZONE" --command="
    cd ~/myapp
    
    # Create production .env
    cat > .env << 'EOF'
DB_USER=myapp
DB_PASSWORD=$(openssl rand -base64 32)
DB_NAME=myapp_db
REDIS_PASSWORD=$(openssl rand -base64 32)
JWT_SECRET=$(openssl rand -base64 48)
API_URL=http://$EXTERNAL_IP:8080
NODE_ENV=production
EOF
    
    # Start services
    docker-compose up -d --build
    
    echo 'Deployment complete!'
"

echo ""
echo "=================================="
echo "  🎉 Deployment Complete!"
echo "=================================="
echo ""
echo "Your application is now running at:"
echo "  Frontend:  http://$EXTERNAL_IP:3000"
echo "  Backend:   http://$EXTERNAL_IP:8080"
echo ""
echo "To SSH into the instance:"
echo "  gcloud compute ssh $INSTANCE_NAME --zone=$ZONE"
echo ""
echo "To view logs:"
echo "  gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command='cd ~/myapp && docker-compose logs -f'"
echo ""
echo "To stop the instance:"
echo "  gcloud compute instances stop $INSTANCE_NAME --zone=$ZONE"
echo ""
echo "To delete the instance:"
echo "  gcloud compute instances delete $INSTANCE_NAME --zone=$ZONE"
echo "=================================="