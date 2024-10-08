# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
resource "aws_codepipeline" "aft_codecommit_customizations_codepipeline" {
  count    = local.vcs.is_codecommit ? 1 : 0
  name     = "${var.account_id}-customizations-pipeline"
  role_arn = data.aws_iam_role.aft_codepipeline_customizations_role.arn

  artifact_store {
    location = data.aws_s3_bucket.aft_codepipeline_customizations_bucket.id
    type     = "S3"

    encryption_key {
      id   = data.aws_kms_alias.aft_key.arn
      type = "KMS"
    }
  }

  ##############################################################
  # Source
  ##############################################################
  stage {
    name = "Source"

    action {
      name             = "aft-global-customizations"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source-aft-global-customizations"]

      configuration = {
        RepositoryName       = data.aws_ssm_parameter.aft_global_customizations_repo_name.value
        BranchName           = data.aws_ssm_parameter.aft_global_customizations_repo_branch.value
        PollForSourceChanges = false
      }
    }

    action {
      name             = "aft-account-customizations"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source-aft-account-customizations"]

      configuration = {
        RepositoryName       = data.aws_ssm_parameter.aft_account_customizations_repo_name.value
        BranchName           = data.aws_ssm_parameter.aft_account_customizations_repo_branch.value
        PollForSourceChanges = false
      }
    }
    
    action {
      name             = "aft-account-vpc"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      input_artifacts  = ["source-aft-account-customizations"]
      output_artifacts = ["source-aft-account-customizations-vpc"]

      configuration = {
        RepositoryName       = "tai4hang/learn-terraform-aft-account-customizations-vpc"
        BranchName           = "main"
        PollForSourceChanges = false
      }
    }
    
    action {
      name             = "aft-account-iam"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      input_artifacts  = ["source-aft-account-customizations"]
      output_artifacts = ["source-aft-account-customizations-iam"]

      configuration = {
        RepositoryName       = "tai4hang/learn-terraform-aft-account-customizations-iam"
        BranchName           = "main"
        PollForSourceChanges = false
      }
    }
    
    action {
      name             = "aft-account-sg"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      input_artifacts  = ["source-aft-account-customizations-vpc"]
      output_artifacts = ["source-aft-account-customizations-sg"]

      configuration = {
        RepositoryName       = "tai4hang/learn-terraform-aft-account-customizations-sg"
        BranchName           = "main"
        PollForSourceChanges = false
      }
    }
  }

  ##############################################################
  # Apply-AFT-Global-Customizations
  ##############################################################

  stage {
    name = "Global-Customizations"
    action {
      name            = "Apply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source-aft-global-customizations"]
      version         = "1"
      run_order       = "2"
      configuration = {
        ProjectName = var.aft_global_customizations_terraform_codebuild_name
        EnvironmentVariables = jsonencode([
          {
            name  = "VENDED_ACCOUNT_ID",
            value = var.account_id,
            type  = "PLAINTEXT"
          }
        ])
      }
    }
  }
  ##############################################################
  # Apply-AFT-Account-Customizations
  ##############################################################
  stage {
    name = "Account-Setup"

    action {
      name            = "Apply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source-aft-account-customizations"]
      version         = "1"
      run_order       = "2"
      configuration = {
        ProjectName = var.aft_account_customizations_terraform_codebuild_name
        EnvironmentVariables = jsonencode([
          {
            name  = "VENDED_ACCOUNT_ID",
            value = var.account_id,
            type  = "PLAINTEXT"
          }
        ])
      }
    }
  }

  ##############################################################
  # Apply-AFT-Account-VPC
  ##############################################################
  stage {
    name = "Account-VPC"

    action {
      name            = "Apply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source-aft-account-customizations-vpc"]
      version         = "1"
      run_order       = "2"
      configuration = {
        ProjectName = "aft-account-customizations-vpc-terraform"
        EnvironmentVariables = jsonencode([
          {
            name  = "VENDED_ACCOUNT_ID",
            value = var.account_id,
            type  = "PLAINTEXT"
          }
        ])
      }
    }
  }

  ##############################################################
  # Apply-AFT-Account-IAM
  ##############################################################
  stage {
    name = "Account-IAM"

    action {
      name            = "Apply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source-aft-account-customizations-iam"]
      version         = "1"
      run_order       = "2"
      configuration = {
        ProjectName = "aft-account-customizations-iam-terraform"
        EnvironmentVariables = jsonencode([
          {
            name  = "VENDED_ACCOUNT_ID",
            value = var.account_id,
            type  = "PLAINTEXT"
          }
        ])
      }
    }
  }

  ##############################################################
  # Apply-AFT-SG
  ##############################################################
  stage {
    name = "Account-SG"

    action {
      name            = "Apply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source-aft-account-customizations-sg"]
      version         = "1"
      run_order       = "2"
      configuration = {
        ProjectName = "aft-account-customizations-sg-terraform"
        EnvironmentVariables = jsonencode([
          {
            name  = "VENDED_ACCOUNT_ID",
            value = var.account_id,
            type  = "PLAINTEXT"
          }
        ])
      }
    }
  }
}

resource "aws_codepipeline" "aft_codestar_customizations_codepipeline" {
  count    = local.vcs.is_codecommit ? 0 : 1
  name     = "${var.account_id}-customizations-pipeline"
  role_arn = data.aws_iam_role.aft_codepipeline_customizations_role.arn

  artifact_store {
    location = data.aws_s3_bucket.aft_codepipeline_customizations_bucket.id
    type     = "S3"

    encryption_key {
      id   = data.aws_kms_alias.aft_key.arn
      type = "KMS"
    }
  }

  ##############################################################
  # Source
  ##############################################################
  stage {
    name = "Source"

    action {
      name             = "aft-global-customizations"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source-aft-global-customizations"]

      configuration = {
        ConnectionArn        = data.aws_ssm_parameter.codestar_connection_arn.value
        FullRepositoryId     = data.aws_ssm_parameter.aft_global_customizations_repo_name.value
        BranchName           = data.aws_ssm_parameter.aft_global_customizations_repo_branch.value
        DetectChanges        = false
        OutputArtifactFormat = "CODE_ZIP"
      }
    }

    action {
      name             = "aft-account-customizations"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source-aft-account-customizations"]

      configuration = {
        ConnectionArn        = data.aws_ssm_parameter.codestar_connection_arn.value
        FullRepositoryId     = data.aws_ssm_parameter.aft_account_customizations_repo_name.value
        BranchName           = data.aws_ssm_parameter.aft_account_customizations_repo_branch.value
        DetectChanges        = false
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
    
    action {
      name             = "aft-account-customizations-vpc"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source-aft-account-customizations-vpc"]

      configuration = {
        ConnectionArn        = data.aws_ssm_parameter.codestar_connection_arn.value
        FullRepositoryId     = "tai4hang/learn-terraform-aft-account-customizations-vpc"
        BranchName           = "main"
        DetectChanges        = false
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
    
    action {
      name             = "aft-account-customizations-iam"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source-aft-account-customizations-iam"]

      configuration = {
        ConnectionArn        = data.aws_ssm_parameter.codestar_connection_arn.value
        FullRepositoryId     = "tai4hang/learn-terraform-aft-account-customizations-iam"
        BranchName           = "main"
        DetectChanges        = false
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
    
    action {
      name             = "aft-account-customizations-sg"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source-aft-account-customizations-sg"]

      configuration = {
        ConnectionArn        = data.aws_ssm_parameter.codestar_connection_arn.value
        FullRepositoryId     = "tai4hang/learn-terraform-aft-account-customizations-sg"
        BranchName           = "main"
        DetectChanges        = false
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  ##############################################################
  # Apply-AFT-Global-Customizations
  ##############################################################

  stage {
    name = "AFT-Global-Customizations"

    action {
      name            = "Apply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source-aft-global-customizations"]
      version         = "1"
      run_order       = "2"
      configuration = {
        ProjectName = var.aft_global_customizations_terraform_codebuild_name
        EnvironmentVariables = jsonencode([
          {
            name  = "VENDED_ACCOUNT_ID",
            value = var.account_id,
            type  = "PLAINTEXT"
          }
        ])
      }
    }

  }
  ##############################################################
  # Apply-AFT-Account-Customizations
  ##############################################################

  stage {
    name = "AFT-Account-Customizations"
    action {
      name            = "Apply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source-aft-account-customizations"]
      version         = "1"
      run_order       = "2"
      configuration = {
        ProjectName = var.aft_account_customizations_terraform_codebuild_name
        EnvironmentVariables = jsonencode([
          {
            name  = "VENDED_ACCOUNT_ID",
            value = var.account_id,
            type  = "PLAINTEXT"
          }
        ])
      }
    }
  }
    ##############################################################
  # Apply-AFT-Account-VPC
  ##############################################################

  stage {
    name = "AFT-Account-Customizations-VPC"
    action {
      name            = "Apply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source-aft-account-customizations-vpc"]
      version         = "1"
      run_order       = "2"
      configuration = {
        ProjectName = "aft-account-customizations-vpc-terraform"
        EnvironmentVariables = jsonencode([
          {
            name  = "VENDED_ACCOUNT_ID",
            value = var.account_id,
            type  = "PLAINTEXT"
          }
        ])
      }
    }
  }
    ##############################################################
  # Apply-AFT-Account-Customizations-IAM
  ##############################################################

  stage {
    name = "AFT-Account-Customizations-IAM"
    action {
      name            = "Apply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source-aft-account-customizations-iam"]
      version         = "1"
      run_order       = "2"
      configuration = {
        ProjectName = "aft-account-customizations-iam-terraform"
        EnvironmentVariables = jsonencode([
          {
            name  = "VENDED_ACCOUNT_ID",
            value = var.account_id,
            type  = "PLAINTEXT"
          }
        ])
      }
    }
  }
  ##############################################################
  # Apply-AFT-Account-Customizations-SG
  ##############################################################

  stage {
    name = "AFT-Account-Customizations-SG"
    action {
      name            = "Apply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source-aft-account-customizations-sg"]
      version         = "1"
      run_order       = "2"
      configuration = {
        ProjectName = "aft-account-customizations-sg-terraform"
        EnvironmentVariables = jsonencode([
          {
            name  = "VENDED_ACCOUNT_ID",
            value = var.account_id,
            type  = "PLAINTEXT"
          }
        ])
      }
    }
  }
}
