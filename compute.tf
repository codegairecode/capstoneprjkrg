# 1. Two ECR Repositories (To store Docker images)
resource "aws_ecr_repository" "telemetry_repo" {
  name                 = "ev-telemetry-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecr_repository" "management_repo" {
  name                 = "ev-management-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# 2. The ECS Cluster (The engine that runs the containers)
resource "aws_ecs_cluster" "ev_cluster" {
  name = "EV-Fleet-Cluster"
}

# 3. IAM Role for ECS Task Execution (Gives ECS permission to pull images from ECR and send logs)
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecsTaskExecutionRole-EVFleet"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 4. ALB Target Groups & Listeners (Connecting the load balancers to the containers)
resource "aws_lb_target_group" "telemetry_tg" {
  name        = "telemetry-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main_vpc.id # References the VPC from network.tf!
  target_type = "ip"
}

resource "aws_lb_listener" "telemetry_listener" {
  load_balancer_arn = aws_lb.alb_telemetry.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.telemetry_tg.arn
  }
}

resource "aws_lb_target_group" "management_tg" {
  name        = "management-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main_vpc.id
  target_type = "ip"
}

resource "aws_lb_listener" "management_listener" {
  load_balancer_arn = aws_lb.alb_management.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.management_tg.arn
  }
}

# 5. Two Task Definitions (The blueprints for the containers)
resource "aws_ecs_task_definition" "telemetry_task" {
  family                   = "telemetry-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # .25 vCPU
  memory                   = "512" # 512 MB RAM
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name      = "telemetry-container"
    image     = "nginxdemos/hello" # Placeholder image
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort      = 80
    }]
  }])
}

resource "aws_ecs_task_definition" "management_task" {
  family                   = "management-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name      = "management-container"
    image     = "nginxdemos/hello" # Placeholder image
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort      = 80
    }]
  }])
}

# 6. Two ECS Services (Keeps the containers running and attached to the Load Balancers)
resource "aws_ecs_service" "telemetry_service" {
  name            = "telemetry-service"
  cluster         = aws_ecs_cluster.ev_cluster.id
  task_definition = aws_ecs_task_definition.telemetry_task.arn
  desired_count   = 2 # Ensures High Availability
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.telemetry_tg.arn
    container_name   = "telemetry-container"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.telemetry_listener]
}

resource "aws_ecs_service" "management_service" {
  name            = "management-service"
  cluster         = aws_ecs_cluster.ev_cluster.id
  task_definition = aws_ecs_task_definition.management_task.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.management_tg.arn
    container_name   = "management-container"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.management_listener]
}