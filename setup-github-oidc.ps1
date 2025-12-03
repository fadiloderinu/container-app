# Setup GitHub OIDC for AWS
# Run this script to configure GitHub Actions authentication with AWS

Write-Host "Setting up GitHub OIDC provider for AWS..."

# 1. Create OIDC Provider
Write-Host "`n[Step 1] Creating OIDC Identity Provider..."
$thumbprint = "6938fd4d98bab03faadb97b34396831e3780aca1"  # GitHub's OIDC thumbprint

$oidcProvider = aws iam create-open-id-connect-provider `
  --url https://token.actions.githubusercontent.com `
  --client-id-list sts.amazonaws.com `
  --thumbprint-list $thumbprint `
  --region us-east-1 2>&1

if ($oidcProvider -match "OpenIDConnectProviderArn") {
    Write-Host "✓ OIDC Provider created successfully"
} else {
    Write-Host "OIDC Provider may already exist or error occurred"
}

# 2. Create IAM Role for GitHub Actions
Write-Host "`n[Step 2] Creating IAM Role for GitHub Actions..."

$trustPolicy = @{
    Version = "2012-10-17"
    Statement = @(
        @{
            Effect = "Allow"
            Principal = @{
                Federated = "arn:aws:iam::505285757529:oidc-provider/token.actions.githubusercontent.com"
            }
            Action = "sts:AssumeRoleWithWebIdentity"
            Condition = @{
                StringEquals = @{
                    "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
                    "token.actions.githubusercontent.com:sub" = "repo:YOUR_GITHUB_USERNAME/container-app:ref:refs/heads/main"
                }
            }
        }
    )
}

$policyJson = $trustPolicy | ConvertTo-Json -Depth 10

aws iam create-role `
  --role-name github-actions-role `
  --assume-role-policy-document $policyJson `
  --region us-east-1 2>&1

Write-Host "✓ IAM Role created"

# 3. Create policy for GitHub Actions role
Write-Host "`n[Step 3] Attaching permissions to GitHub Actions role..."

$permissions = @{
    Version = "2012-10-17"
    Statement = @(
        @{
            Effect = "Allow"
            Action = @(
                "ecr:GetAuthorizationToken",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload"
            )
            Resource = "arn:aws:ecr:us-east-1:505285757529:repository/oderinu-api"
        },
        @{
            Effect = "Allow"
            Action = @(
                "ecs:UpdateService",
                "ecs:DescribeServices",
                "ecs:DescribeTaskDefinition",
                "ecs:DescribeCluster"
            )
            Resource = @(
                "arn:aws:ecs:us-east-1:505285757529:service/oderinu-api-cluster/oderinu-api-service",
                "arn:aws:ecs:us-east-1:505285757529:task-definition/oderinu-api:*"
            )
        },
        @{
            Effect = "Allow"
            Action = "iam:PassRole"
            Resource = @(
                "arn:aws:iam::505285757529:role/oderinu-api-ecs-task-execution-role",
                "arn:aws:iam::505285757529:role/oderinu-api-ecs-task-role"
            )
        }
    )
}

$policyJson = $permissions | ConvertTo-Json -Depth 10

aws iam put-role-policy `
  --role-name github-actions-role `
  --policy-name github-actions-policy `
  --policy-document $policyJson `
  --region us-east-1 2>&1

Write-Host "✓ Permissions attached"

# 4. Create GitHub secret
Write-Host "`n[Step 4] GitHub Setup Required"
Write-Host "Run these commands in your GitHub repository settings:"
Write-Host "  1. Go to Settings → Secrets and Variables → Actions"
Write-Host "  2. Create new secret: AWS_ACCOUNT_ID = 505285757529"
Write-Host "`nOr use GitHub CLI:"
Write-Host "  gh secret set AWS_ACCOUNT_ID --body 505285757529"

Write-Host "`n[Step 5] Update GitHub Actions Workflow"
Write-Host "Replace YOUR_GITHUB_USERNAME in the role-to-assume ARN:"
Write-Host "  arn:aws:iam::505285757529:role/github-actions-role"
Write-Host "`nWith your actual GitHub username in .github/workflows/deploy.yml"

Write-Host "`n✓ Setup complete!"
