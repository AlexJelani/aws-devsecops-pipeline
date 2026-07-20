# Default Networking Configuration
resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = "${var.region}a"
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = "${var.region}b"
}

# EKS Cluster
module "default_cluster" {
  source       = "./modules/eks"
  cluster_name = "${var.resource_prefix}-devsecops-cluster"
  subnet_ids = [
    aws_default_subnet.default_subnet_a.id,
    aws_default_subnet.default_subnet_b.id
  ]
  kubernetes_version          = "1.36"
  node_group_min_size         = 1
  node_group_max_size         = 3
  node_group_desired_capacity = 2
  instance_types              = ["t3.medium"]
  node_group_disk_size        = 20
}