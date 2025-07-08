#!/bin/bash

# ---- CONFIGURATION ----
export STACK_NAME="insurance-app-demo"
export AWS_REGION="us-east-1"
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ARTIFACT_BUCKET_NAME="${STACK_NAME}-resources-${ACCOUNT_ID}-${AWS_REGION}"

# ---- DELETE STACK ----
echo "Deleting CloudFormation Stack: ${STACK_NAME}"
aws cloudformation delete-stack --stack-name ${STACK_NAME} --region ${AWS_REGION}
aws cloudformation wait stack-delete-complete --stack-name ${STACK_NAME} --region ${AWS_REGION}
echo "✅ CloudFormation Stack deleted."

# ---- DELETE S3 BUCKET ----
echo "Emptying and Deleting S3 Bucket: ${ARTIFACT_BUCKET_NAME}"
aws s3 rm s3://${ARTIFACT_BUCKET_NAME} --region ${AWS_REGION} --recursive
aws s3 rb s3://${ARTIFACT_BUCKET_NAME} --region ${AWS_REGION}
echo "✅ S3 Bucket deleted."
