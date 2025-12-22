# --- Dados da Conta e do GitHub OIDC ---
data "aws_caller_identity" "current" {}

# --- Repositório GitHub ---
variable "github_repo" {
  default = "ramonriserio/my-project" 
}

# --- Role de Deploy (Que o GitHub Actions assume) ---
resource "aws_iam_role" "github_actions_role" {
  name = "lacrei_github_actions_deploy_role_${terraform.workspace}"

  # Trust Policy: Permite que o GitHub OIDC assuma esta role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub": "repo:${var.github_repo}:*"
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# --- As Permissões Mínimas (Policy) --- 
resource "aws_iam_policy" "pipeline_permissions" {
  name = "lacrei_github_actions_minimal_policy_${terraform.workspace}"
  description = "Permissões mínimas para o Terraform criar a infraestrutura"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Gerenciamento do Estado (S3 e DynamoDB) - FUNDAMENTAL
      {
        Sid    = "TerraformStateBackend"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = [
          "arn:aws:s3:::lacrei-terraform-state-backend",      # Seu Bucket
          "arn:aws:s3:::lacrei-terraform-state-backend/*",
          "arn:aws:dynamodb:*:*:table/terraform-lock-table"   # Sua Tabela
        ]
      },

      # EC2 e VPC (Networking e Computação)
      # Nota: EC2/VPC é difícil restringir recurso a recurso, pois criar uma VPC exige muitas ações.
      # Restringimos por Região e Ações.
      {
        Sid    = "InfraManagement"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:StopInstances",
          "ec2:StartInstances",
          "ec2:Describe*",           # Leitura geral necessária para o Terraform planejar
          "ec2:CreateTags",
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:ModifyVpcAttribute",
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:CreateInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:CreateRouteTable",
          "ec2:DeleteRouteTable",
          "ec2:AssociateRouteTable",
          "ec2:DisassociateRouteTable",
          "ec2:CreateRoute",
          "ec2:DeleteRoute"
        ]
        Resource = "*"
      },

      # IAM (Permite criar a Role da EC2 para Observabilidade)
      # PERIGO: Aqui restringimos para ele só poder criar/alterar Roles que comecem com "lacrei_"
      # Isso impede que o Pipeline vire Admin criando uma role de Admin para si mesmo.
      {
        Sid    = "IAMManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:GetRole",
          "iam:ListRoles",
          "iam:DeleteRole",
          "iam:PassRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListInstanceProfiles",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies"
        ]
        Resource = [
          "arn:aws:iam::*:role/lacrei_*",           # Roles da aplicação
          "arn:aws:iam::*:role/github-actions-*",   # Permitir atualizar a si mesma (opcional)
          "arn:aws:iam::*:instance-profile/lacrei_*",
          "arn:aws:iam::*:policy/lacrei_*"
        ]
      },
      
      # 4. Logs (Para criar o Log Group)
      {
        Sid = "LogsManagement"
        Effect = "Allow"
        Action = [
            "logs:CreateLogGroup",
            "logs:DeleteLogGroup",
            "logs:DescribeLogGroups",
            "logs:PutRetentionPolicy",
            "logs:ListTagsLogGroup"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/lacrei/*"
      }
    ]
  })
}

# --- 4. Conecta a Policy à Role ---
resource "aws_iam_role_policy_attachment" "attach_deploy" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.pipeline_permissions.arn
}

# --- 5. Output do ARN para você colocar no GitHub Secrets ---
output "deploy_role_arn" {
  value = aws_iam_role.github_actions_role.arn
}