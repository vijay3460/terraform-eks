resource "aws_vpc" "vpc" {
  cidr_block = "${var.cidr_vpc}"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags {
    "Environment" = "${var.environment_tag}"
    "Name"        = "my-vpc"
    "kubernetes.io/cluster/${var.cluster-name}" = "shared"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"
  tags {
    "Environment" = "${var.environment_tag}"
  }
}

resource "aws_subnet" "public-subnet-1a" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.public-subnet-1a}"
  map_public_ip_on_launch = "true"
  availability_zone = "${var.az-1a}"
  tags {
    "Environment" = "${var.environment_tag}"
    "Name"        = "public-subnet-1a"
    "kubernetes.io/cluster/${var.cluster-name}" = "shared"
  }
}

resource "aws_subnet" "public-subnet-1b" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.public-subnet-1b}"
  map_public_ip_on_launch = "true"
  availability_zone = "${var.az-1b}"
  tags {
    "Environment" = "${var.environment_tag}"
    "Name"        = "public-subnet-1b"
    "kubernetes.io/cluster/${var.cluster-name}" = "shared"
  }
}

resource "aws_subnet" "private-subnet-1a" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.private-subnet-1a}"
  availability_zone = "${var.az-1a}"
  tags {
    "Environment" = "${var.environment_tag}"
    "Name"        = "private-subnet-1a"
    "kubernetes.io/cluster/${var.cluster-name}" = "shared"
  }
}

resource "aws_subnet" "private-subnet-1b" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.private-subnet-1b}"
  availability_zone = "${var.az-1b}"
  tags {
    "Environment" = "${var.environment_tag}"
    "Name"        = "private-subnet-1a"
    "kubernetes.io/cluster/${var.cluster-name}" = "shared"
  }
}

resource "aws_route_table" "public-rt" {
  vpc_id = "${aws_vpc.vpc.id}"
route {
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_internet_gateway.igw.id}"
  }
tags {
    "Environment" = "${var.environment_tag}"
  }
}

resource "aws_route_table_association" "public-rt-subnets" {
  subnet_id      = "${aws_subnet.public-subnet-1a.id}"
  route_table_id = "${aws_route_table.public-rt.id}"
}
resource "aws_route_table_association" "public-rt-subnets-1b" {
  subnet_id      = "${aws_subnet.public-subnet-1b.id}"
  route_table_id = "${aws_route_table.public-rt.id}"
}

resource "aws_eip" "terraformtraining-nat" {
vpc      = true
}
resource "aws_nat_gateway" "terraformtraining-nat-gw" {
allocation_id = "${aws_eip.terraformtraining-nat.id}"
subnet_id = "${aws_subnet.public-subnet-1a.id}"
depends_on = ["aws_internet_gateway.igw"]
}

resource "aws_route_table" "private-rt" {
    vpc_id = "${aws_vpc.vpc.id}"
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = "${aws_nat_gateway.terraformtraining-nat-gw.id}"
    }

    tags {
        "Environment" = "${var.environment_tag}"
    }
}

resource "aws_route_table_association" "private-rt-subnets" {
  subnet_id      = "${aws_subnet.private-subnet-1a.id}"
  route_table_id = "${aws_route_table.private-rt.id}"
}
resource "aws_route_table_association" "private-rt-subnets-1b" {
  subnet_id      = "${aws_subnet.private-subnet-1b.id}"
  route_table_id = "${aws_route_table.private-rt.id}"
}

#=======================================EKS Cluster && ROLE============================================

resource "aws_iam_role" "eks-role" {
  name_prefix = "${var.cluster-name}-eks-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "eks-policy" {
  name_prefix = "${var.cluster-name}-eks-policy"
  role = "${aws_iam_role.eks-role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "eks:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.eks-role.name}"
}

resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.eks-role.name}"
}

resource "aws_security_group" "clustersg" {
  name        = "eks-${var.cluster-name}"
  description = "Cluster communication with worker nodes"
  vpc_id      = "${aws_vpc.vpc.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port         = 443
    to_port           = 443
    protocol          = "tcp"
    cidr_blocks       = ["${local.client-cidr}", "${aws_vpc.vpc.cidr_block}"]
    description       = "Allow access to the cluster API Server"
  }


  tags = {
    Name = "eks-${var.cluster-name}"
  }
}


resource "aws_eks_cluster" "cluster" {
  name     = "${var.cluster-name}"
  role_arn = "${aws_iam_role.eks-role.arn}"
  version  = "1.14"

  vpc_config {
    security_group_ids = ["${aws_security_group.clustersg.id}"]
    subnet_ids         = ["${aws_subnet.public-subnet-1a.id}", "${aws_subnet.public-subnet-1b.id}"]
  }

  depends_on = [
    "aws_iam_role_policy_attachment.cluster-AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.cluster-AmazonEKSServicePolicy",
  ]
}

#========================kubeconfig update with cluster=====================================
locals {
  kubeconfig = <<KUBECONFIG


apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.cluster.endpoint}
    certificate-authority-data: ${aws_eks_cluster.cluster.certificate_authority.0.data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${var.cluster-name}"
KUBECONFIG
}

output "kubeconfig" {
  value = "${local.kubeconfig}"
}
#===========================================Role for WORKER NODES================================
resource "aws_iam_role" "worker-node" {
  name_prefix = "${var.cluster-name}-node-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

locals {
  config_map_aws_auth = <<CONFIGMAPAWSAUTH
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.worker-node.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAPAWSAUTH
}



resource "aws_iam_role_policy_attachment" "worker-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.worker-node.name}"
}

resource "aws_iam_role_policy_attachment" "worker-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.worker-node.name}"
}

resource "aws_iam_role_policy_attachment" "worker-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.worker-node.name}"
}


#================================SG FOR WORKER NODES=========================
resource "aws_iam_instance_profile" "worker-node" {
  name = "${var.cluster-name}-eks-profile"
  role = "${aws_iam_role.worker-node.name}"
}

resource "aws_security_group" "worker-node" {
  name = "eks-worker-node-${var.cluster-name}"
  description = "Security group for all nodes in the cluster"
  vpc_id = "${aws_vpc.vpc.id}"

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["${aws_vpc.vpc.cidr_block}"]
  }

  ingress {
    from_port = 1025
    to_port = 65535
    protocol = "tcp"
    security_groups = ["${aws_security_group.clustersg.id}"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["${local.client-cidr}"]
  }


  tags = {
    "Name" = "eks-${var.cluster-name}-worker-node"
    "kubernetes.io/cluster/${var.cluster-name}" = "owned"
  }
}

# Userdata for workers.
locals {
  milpa-worker-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.cluster.endpoint}' --b64-cluster-ca '${aws_eks_cluster.cluster.certificate_authority.0.data}' '${var.cluster-name}'
USERDATA
}

resource "aws_launch_configuration" "milpa-worker" {
  associate_public_ip_address = false
  iam_instance_profile = "${aws_iam_instance_profile.worker-node.name}"
  image_id = "${var.eks-ami}"
  instance_type = "t2.small"
  name_prefix = "${var.cluster-name}-eks-launch-configuration"
  security_groups = ["${aws_security_group.worker-node.id}"]
  user_data = "${local.milpa-worker-userdata}"
  key_name = "${var.key}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "milpa-workers" {
  desired_capacity = 1
  launch_configuration = "${aws_launch_configuration.milpa-worker.id}"
  max_size = 1
  min_size = 1
  name = "${var.cluster-name}-milpa-workers"
  vpc_zone_identifier = ["${aws_subnet.private-subnet-1a.id}", "${aws_subnet.private-subnet-1b.id}"]


tag {
  key = "Name"
    value = "eks-${var.cluster-name}-milpa-workers"
    propagate_at_launch = true  
  }

  tag {
    key = "kubernetes.io/cluster/${var.cluster-name}"
    value = "owned"
    propagate_at_launch = true  
}
}



