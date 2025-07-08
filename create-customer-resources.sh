#!/bin/bash

# ---- USER CONFIGURATION ----
export STACK_NAME="insurance-app-demo"                      # Lowercase only
export SNS_EMAIL="your-email@example.com"                   # Update to your email
export EVIDENCE_UPLOAD_URL="https://example.com/upload"     # Update to your actual URL
export AWS_REGION="us-east-1"                              # Your AWS Region

# ---- SYSTEM VARIABLES ----
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ARTIFACT_BUCKET_NAME="${STACK_NAME}-resources-${ACCOUNT_ID}-${AWS_REGION}"
export DATA_LOADER_KEY="agent/lambda/data-loader/loader_deployment_package.zip"
export CREATE_CLAIM_KEY="agent/lambda/action-groups/create_claim.zip"
export GATHER_EVIDENCE_KEY="agent/lambda/action-groups/gather_evidence.zip"
export SEND_REMINDER_KEY="agent/lambda/action-groups/send_reminder.zip"

# ---- CREATE S3 BUCKET ----
echo "Creating S3 bucket: ${ARTIFACT_BUCKET_NAME}"
aws s3 mb s3://${ARTIFACT_BUCKET_NAME} --region ${AWS_REGION} || echo "Bucket may already exist, continuing..."

# ---- UPLOAD FILES TO S3 ----
echo "Uploading agent files to S3..."
aws s3 cp ../agent/ s3://${ARTIFACT_BUCKET_NAME}/agent/ \
    --region ${AWS_REGION} \
    --recursive \
    --exclude ".DS_Store" \
    --exclude "*/.DS_Store"

# ---- CREATE LAMBDA LAYERS ----
echo "Publishing Bedrock Agents Lambda Layer..."
export BEDROCK_AGENTS_LAYER_ARN=$(aws lambda publish-layer-version \
    --layer-name bedrock-agents-and-function-calling \
    --description "Agents for Bedrock Layer" \
    --license-info "MIT" \
    --content S3Bucket=${ARTIFACT_BUCKET_NAME},S3Key=agent/lambda/lambda-layer/bedrock-agents-layer.zip \
    --compatible-runtimes python3.11 \
    --region ${AWS_REGION} \
    --query LayerVersionArn --output text)

echo "Publishing cfnresponse Lambda Layer..."
export CFNRESPONSE_LAYER_ARN=$(aws lambda publish-layer-version \
    --layer-name cfnresponse \
    --description "cfnresponse Layer" \
    --license-info "MIT" \
    --content S3Bucket=${ARTIFACT_BUCKET_NAME},S3Key=agent/lambda/lambda-layer/cfnresponse-layer.zip \
    --compatible-runtimes python3.11 \
    --region ${AWS_REGION} \
    --query LayerVersionArn --output text)

# ---- DEPLOY STACK ----
echo "Deploying CloudFormation Stack: ${STACK_NAME}"
aws cloudformation deploy \
    --stack-name ${STACK_NAME} \
    --template-file ../cfn/bedrock-customer-resources.yml \
    --parameter-overrides \
        ArtifactBucket=${ARTIFACT_BUCKET_NAME} \
        DataLoaderKey=${DATA_LOADER_KEY} \
        CreateClaimKey=${CREATE_CLAIM_KEY} \
        GatherEvidenceKey=${GATHER_EVIDENCE_KEY} \
        SendReminderKey=${SEND_REMINDER_KEY} \
        BedrockAgentsLayerArn=${BEDROCK_AGENTS_LAYER_ARN} \
        CfnresponseLayerArn=${CFNRESPONSE_LAYER_ARN} \
        SNSEmail=${SNS_EMAIL} \
        EvidenceUploadUrl=${EVIDENCE_UPLOAD_URL} \
    --capabilities CAPABILITY_NAMED_IAM \
    --region ${AWS_REGION}

echo "✅ Stack deployment initiated. Check status in the AWS CloudFormation console or use the command below:"
echo "aws cloudformation describe-stacks --stack-name ${STACK_NAME} --region ${AWS_REGION} --query \"Stacks[0].StackStatus\""

