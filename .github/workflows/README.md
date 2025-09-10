# Terraform GitHub Actions Workflows - User Guide

## 📁 File Structure

Create the following files inside .github/workflows/:

```shell
.github/
└── workflows/
    ├── terraform-plan.yml     # Automatic planning
    └── terraform-apply.yml    # Apply on demand
```

## 🚀 Features

1. Automatic Planning (terraform-plan.yml)

    **Triggers**:

    * On every Pull Request to the main branch
    * When files in terraform/ or terraform/modules/ change
    * Manually via the comment @bot plan

    **What it does**:

    * Checks Terraform formatting (terraform fmt)
    * Initializes Terraform
    * Validates the configuration
    * Generates plans for dev and prod environments
    * Saves the plan as an artifact
    * Adds a comment with results to the PR

2. On-Demand Apply (terraform-apply.yml)

    **Triggers**:

    When someone with proper permissions writes a comment:

    * @bot run apply – applies the saved plan
    * @bot reapply – generates a new plan and applies it immediately

    **What it does**:

    * Verifies user permissions
    * Downloads the plan from artifacts (for apply) or generates a new one (for reapply)
    * Applies changes with Terraform
    * Adds a comment with results

## 🎯 Available PR Commands

| Command | Description |
| ------- | ----------- |
|@bot plan |Runs planning again |
|@bot apply | Applies the saved plan for all environments |
|@bot apply env=dev | Applies the plan only for the dev environment |
|@bot apply env=prod | Applies the plan only for the prod environment |
|@bot reapply | Generates a new plan and applies it immediately |
|@bot reapply env=dev | Reapply only for dev |

## ⚙️ Required GitHub Secrets

Add the following secrets in the repository settings:

```shell
AWS_ACCESS_KEY_ID       # AWS Access Key
AWS_SECRET_ACCESS_KEY   # AWS Secret Key  
AWS_REGION              # AWS region (e.g., eu-west-1)
TF_STATE_BUCKET         # S3 bucket name for Terraform state
```

## 🔐 Permissions

Plan: Anyone with read/write/admin access can trigger planning

Apply: Only users with write/admin permissions can apply changes

## 📂 Terraform Directory Structure

The workflow assumes the following structure:

```shell
terraform/
├── dev/
│   ├── main.tf
│   ├── variables.tf
│   └── terraform.tfvars
├── prod/
│   ├── main.tf
│   ├── variables.tf
│   └── terraform.tfvars
└── modules/
    └── # your modules
```

## 🔄 Workflow

1. Create a PR with Terraform changes
2. Plan runs automatically – a comment with results will appear
3. Review the changes in the comment
4. Apply changes with the comment @bot run apply
5. Check results in the follow-up comment

## 🚨 Troubleshooting

Problem: "No plan file found"  
Solution: Use @bot reapply instead of @bot run apply  

Problem: "You do not have permission"  
Solution: Ask an maintainer to grant you write access

Problem: Apply did not start  
Solution: Ensure your comment is exactly `@bot run apply`

Problem: Plan shows AWS errors  
Solution: Verify AWS secrets are set correctly
