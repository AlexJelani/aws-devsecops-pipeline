#!/bin/bash
# Cleanup script for AWS resources
# This script identifies and optionally removes orphaned/unexpected resources

set -e

REGION="us-east-1"
RESOURCE_PREFIX="dsb"

echo "=== AWS Resource Cleanup Script ==="
echo "Region: $REGION"
echo "Resource Prefix: $RESOURCE_PREFIX"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to list resources
list_resources() {
    echo -e "${GREEN}=== Checking EKS Clusters ===${NC}"
    aws eks list-clusters --region $REGION --query 'clusters[?starts_with(@, `'$RESOURCE_PREFIX'`)]' --output table
    
    echo -e "${GREEN}=== Checking EC2 Instances ===${NC}"
    aws ec2 describe-instances --region $REGION --filters "Name=tag:Name,Values=*$RESOURCE_PREFIX*" --query 'Reservations[].Instances[].{Instance:InstanceId,Type:InstanceType,State:State.Name}' --output table
    
    echo -e "${GREEN}=== Checking S3 Buckets ===${NC}"
    aws s3 ls --region $REGION | grep $RESOURCE_PREFIX || echo "No buckets found with prefix $RESOURCE_PREFIX"
    
    echo -e "${GREEN}=== Checking ELBs ===${NC}"
    aws elb describe-load-balancers --region $REGION --query 'LoadBalancerDescriptions[?starts_with(Type, `'$RESOURCE_PREFIX'`)]' --output table 2>/dev/null || echo "No Classic ELBs found"
    aws elbv2 describe-load-balancers --region $REGION --query 'LoadBalancers[?starts_with(TagDescription.Tags[?Key==`Name`].Value, `'$RESOURCE_PREFIX'`)]' --output table 2>/dev/null || echo "No Application/Network ELBs found"
    
    echo -e "${GREEN}=== Checking ECR Repositories ===${NC}"
    aws ecr describe-repositories --region $REGION --query 'repositories[?starts_with(repositoryName, `'$RESOURCE_PREFIX'`)].repositoryName' --output table 2>/dev/null || echo "No ECR repositories found"
    
    echo -e "${GREEN}=== Checking IAM Roles ===${NC}"
    aws iam list-roles --region $REGION --query 'Roles[?starts_with(RoleName, `'$RESOURCE_PREFIX'`)].RoleName' --output table
}

# Function to delete resources
delete_resources() {
    echo -e "${YELLOW}=== Deleting EKS Node Groups ===${NC}"
    for cluster in $(aws eks list-clusters --region $REGION --query 'clusters[?starts_with(@, `'$RESOURCE_PREFIX'`)]' --output text); do
        echo "Processing cluster: $cluster"
        # Get node groups
        node_groups=$(aws eks list-node-groups --region $REGION --cluster-name $cluster --query 'nodegroups' --output text)
        for ng in $node_groups; do
            echo "  Deleting node group: $ng"
            aws eks delete-nodegroup --region $REGION --cluster-name $cluster --nodegroup-name $ng
        done
    done
    
    echo -e "${YELLOW}=== Deleting EKS Clusters ===${NC}"
    for cluster in $(aws eks list-clusters --region $REGION --query 'clusters[?starts_with(@, `'$RESOURCE_PREFIX'`)]' --output text); do
        echo "Deleting cluster: $cluster"
        aws eks delete-cluster --region $REGION --name $cluster
    done
    
    echo -e "${YELLOW}=== Deleting EC2 Instances ===${NC}"
    aws ec2 describe-instances --region $REGION --filters "Name=tag:Name,Values=*$RESOURCE_PREFIX*" --query 'Reservations[].Instances[].InstanceId' --output text | xargs -I {} aws ec2 terminate-instances --region $REGION --instance-ids {}
    
    echo -e "${YELLOW}=== Deleting ELBs ===${NC}"
    aws elbv2 describe-load-balancers --region $REGION --query 'LoadBalancers[?starts_with(TagDescription.Tags[?Key==`Name`].Value, `'$RESOURCE_PREFIX'`)].LoadBalancerArn' --output text | xargs -I {} aws elbv2 delete-load-balancer --region $REGION --load-balancer-arn {}
    
    echo -e "${YELLOW}=== Deleting ECR Repositories ===${NC}"
    aws ecr describe-repositories --region $REGION --query 'repositories[?starts_with(repositoryName, `'$RESOURCE_PREFIX'`)].repositoryName' --output text | xargs -I {} aws ecr delete-repository --region $REGION --repository-name {} --force
    
    echo -e "${YELLOW}=== Deleting IAM Roles ===${NC}"
    aws iam list-roles --region $REGION --query 'Roles[?starts_with(RoleName, `'$RESOURCE_PREFIX'`)].RoleName' --output text | xargs -I {} aws iam delete-role --region $REGION --role-name {}
}

# Main
case "${1:-list}" in
    list|check)
        echo -e "${GREEN}=== Listing Resources ===${NC}"
        list_resources
        ;;
    delete)
        echo -e "${RED}=== Deleting Resources ===${NC}"
        delete_resources
        echo -e "${GREEN}Cleanup complete!${NC}"
        ;;
    *)
        echo "Usage: $0 [list|delete]"
        echo "  list  - List resources (default)"
        echo "  delete - Delete resources matching prefix $RESOURCE_PREFIX"
        exit 1
        ;;
esac
