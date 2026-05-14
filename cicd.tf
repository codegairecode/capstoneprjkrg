# ==========================================
# 1. IAM ROLES (Least Privilege for CI/CD)
# ==========================================

# CodeBuild Role
resource "aws_iam_role" "codebuild_role" {
  name = "EVFleet-CodeBuild-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_admin" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess" # Using broad access
}

# CodeDeploy Role
resource "aws_iam_role" "codedeploy_role" {
  name = "EVFleet-CodeDeploy-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "codedeploy.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_ecs" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

# CodePipeline Role
resource "aws_iam_role" "codepipeline_role" {
  name = "EVFleet-CodePipeline-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codepipeline_admin" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ==========================================
# 2. CODEBUILD PROJECTS (The Docker Builders)
# ==========================================

resource "aws_codebuild_project" "build_telemetry" {
  name         = "Build-EV-Telemetry"
  service_role = aws_iam_role.codebuild_role.arn
  
  artifacts { type = "CODEPIPELINE" }
  
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true # Required to build Docker images!
  }
  
  source { type = "CODEPIPELINE" }
}

resource "aws_codebuild_project" "build_management" {
  name         = "Build-EV-Management"
  service_role = aws_iam_role.codebuild_role.arn
  
  artifacts { type = "CODEPIPELINE" }
  
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true 
  }
  
  source { type = "CODEPIPELINE" }
}

# ==========================================
# 3. CODEDEPLOY APPLICATIONS (Blue/Green Deployers)
# ==========================================

resource "aws_codedeploy_app" "telemetry_app" {
  compute_platform = "ECS"
  name             = "EV-Telemetry-App"
}

resource "aws_codedeploy_app" "management_app" {
  compute_platform = "ECS"
  name             = "EV-Management-App"
}

# ==========================================
# 4. CODEPIPELINE (The Orchestrator)
# ==========================================

resource "aws_codepipeline" "ev_fleet_pipeline" {
  name     = "EV-Fleet-Master-Pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket # References your bucket from data.tf!
    type     = "S3"
  }

  # Stage 1: SOURCE (Where the code comes from)
  stage {
    name = "Source"
    action {
      name             = "SourceAction"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["source_output"]
      
      configuration = {
        S3Bucket             = aws_s3_bucket.pipeline_artifacts.bucket
        S3ObjectKey          = "source.zip" # Pipeline triggers when this zip is uploaded
        PollForSourceChanges = "true"
      }
    }
  }

  # Stage 2: PARALLEL BUILDS
  stage {
    name = "Parallel-Builds"
    
    action {
      name             = "Build-Telemetry"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_telemetry_output"]
      version          = "1"
      configuration    = { ProjectName = aws_codebuild_project.build_telemetry.name }
      run_order        = 1
    }

    action {
      name             = "Build-Management"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_management_output"]
      version          = "1"
      configuration    = { ProjectName = aws_codebuild_project.build_management.name }
      run_order        = 1 # Same run order means they build at the exact same time!
    }
  }

  # Stage 3: PARALLEL DEPLOYS (Standard ECS Rolling Update)
  stage {
    name = "Parallel-Deploys"

    action {
      name            = "Deploy-Telemetry"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["build_telemetry_output"]
      version         = "1"
      run_order       = 1
      configuration = {
        ClusterName = aws_ecs_cluster.ev_cluster.name
        ServiceName = aws_ecs_service.telemetry_service.name
        FileName    = "telemetry-def.json"
      }
    }

    action {
      name            = "Deploy-Management"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["build_management_output"]
      version         = "1"
      run_order       = 1
      configuration = {
        ClusterName = aws_ecs_cluster.ev_cluster.name
        ServiceName = aws_ecs_service.management_service.name
        FileName    = "management-def.json"
      }
    }
  }
}