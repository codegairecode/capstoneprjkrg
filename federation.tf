# A. Create the Group in Azure Entra ID
resource "azuread_group" "devops_team" {
  display_name     = "AWS-DevOpsEngineers"
  security_enabled = true
  description      = "Group for EV Fleet project DevOps engineers"
}

# B. Create the SAML Provider in AWS
# WARNING: This requires the 'entra-metadata.xml' file to exist in your folder!
resource "aws_iam_saml_provider" "entra_id_provider" {
  name                   = "AzureEntraID-SSO"
  saml_metadata_document = file("${path.module}/entra-metadata.xml") 
}

# C. Define the Trust Policy
data "aws_iam_policy_document" "saml_trust_policy" {
  statement {
    actions = ["sts:AssumeRoleWithSAML"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_saml_provider.entra_id_provider.arn] 
    }

    condition {
      test     = "StringEquals"
      variable = "SAML:aud"
      values   = ["https://signin.aws.amazon.com/saml"]
    }
  }
}

# D. Create the IAM Role in AWS
resource "aws_iam_role" "devops_engineer_role" {
  name               = "DevOpsEngineer-Role"
  assume_role_policy = data.aws_iam_policy_document.saml_trust_policy.json
}

# E. Attach Admin Permissions to that Role
resource "aws_iam_role_policy_attachment" "devops_admin_access" {
  role       = aws_iam_role.devops_engineer_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess" 
}