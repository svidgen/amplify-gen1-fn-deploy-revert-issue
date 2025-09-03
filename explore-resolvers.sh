#!/bin/bash
# Amplify AppSync Configuration Drift Detector
# Identifies mismatches between current AppSync state and CloudFormation expectations
set -e
# Parameters - customer needs to provide these
if [ $# -lt 3 ]; then
    echo "Usage: $0 <API_ID> <REGION> <STACK_NAME>"
    echo "Example: $0 abc123def456 us-east-1 amplify-myapp-staging-ConnectionStack"
    exit 1
fi
API_ID="$1"
REGION="$2"
STACK_NAME="$3"
echo "🔍 Amplify AppSync Drift Detection"
echo "=================================="
echo "API ID: $API_ID"
echo "Region: $REGION"
echo "Stack: $STACK_NAME"
echo ""
# Get all resolver types from AppSync
echo "📋 Current AppSync Types:"
aws appsync list-types --api-id $API_ID --region $REGION --format SDL --output table --no-cli-pager
echo ""
echo "🔍 Resolver Analysis by Type:"
# Get all types and check resolvers on each
TYPES=$(aws appsync list-types --api-id $API_ID --region $REGION --query 'types[].name' --format SDL --output text)
for type in $TYPES; do
    echo ""
    echo "Type: $type"
    RESOLVERS=$(aws appsync list-resolvers --api-id $API_ID --type-name $type --region $REGION --query 'Resolvers[].FieldName' --output text)
    if [ -n "$RESOLVERS" ]; then
        echo "  Resolvers: $RESOLVERS"
    else
        echo "  No resolvers"
    fi
done
echo ""
echo "🏗️  CloudFormation Expected Configuration:"
echo "Getting CloudFormation template expectations..."
# Get the CloudFormation template to see what it expects
aws cloudformation get-template --stack-name $STACK_NAME --region $REGION --query 'TemplateBody.Resources' --output json > /tmp/cfn_template.json
# Look for resolver resources
echo "Resolver resources in CloudFormation:"
jq -r 'to_entries[] | select(.value.Type == "AWS::AppSync::Resolver") | "\(.key): \(.value.Properties.TypeName).\(.value.Properties.FieldName)"' /tmp/cfn_template.json
echo ""
echo "🎯 Next Steps:"
echo "1. Compare actual resolvers (above) with CloudFormation expectations"
echo "2. Look for resolvers that exist on different types than expected"
echo "3. Identify any resolvers that were manually moved between types"
rm -f /tmp/cfn_template.json
