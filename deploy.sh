#!/bin/bash

# Set variables
PROJECT_ID="your-gcp-project-id"
IMAGE_NAME="aiaiodex_tee_image"
ORACLE_KEY="your-oracle-key"
ZONE="your-gcp-zone"
INSTANCE_NAME="your-instance-name"

# Authenticate with Google Cloud
gcloud auth login
gcloud config set project $PROJECT_ID

# Create an enclave
gcloud compute instances create $INSTANCE_NAME \
  --zone=$ZONE \
  --image=$IMAGE_NAME \
  --metadata=ORACLE_KEY=$ORACLE_KEY

# Deploy the application
gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command "
  mkdir -p /app && cd /app
  git clone https://github.com/lotusXRP/LotusFLR-DEV.git .
  pip install -r requirements.txt
  python run_app.py
"

# Clean up
gcloud compute instances delete $INSTANCE_NAME --zone=$ZONE --quiet