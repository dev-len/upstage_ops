resource "aws_security_group" "main_node" {
  name        = "${var.name_prefix}-main-node-sg"
  description = "Bootstrap security group for the K3S server node"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-main-node-sg"
    Role = "k3s-server-bootstrap"
  }
}

resource "aws_security_group" "sub_node" {
  name        = "${var.name_prefix}-sub-node-sg"
  description = "Bootstrap security group shared by K3S worker nodes"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-sub-node-sg"
    Role = "k3s-worker-shared-bootstrap"
  }
}

resource "aws_vpc_security_group_ingress_rule" "main_ssh" {
  security_group_id = aws_security_group.main_node.id
  cidr_ipv4         = var.admin_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "SSH from admin"
}

resource "aws_vpc_security_group_ingress_rule" "sub_ssh" {
  security_group_id = aws_security_group.sub_node.id
  cidr_ipv4         = var.admin_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "SSH from admin"
}

resource "aws_vpc_security_group_ingress_rule" "main_k3s_api_from_sub" {
  security_group_id            = aws_security_group.main_node.id
  referenced_security_group_id = aws_security_group.sub_node.id
  from_port                    = 6443
  to_port                      = 6443
  ip_protocol                  = "tcp"
  description                  = "K3S API from shared worker nodes"
}

resource "aws_vpc_security_group_ingress_rule" "main_k3s_api_from_admin" {
  security_group_id = aws_security_group.main_node.id
  cidr_ipv4         = var.admin_cidr
  from_port         = 6443
  to_port           = 6443
  ip_protocol       = "tcp"
  description       = "K3S API from admin"
}

resource "aws_vpc_security_group_ingress_rule" "main_flannel_from_main" {
  security_group_id            = aws_security_group.main_node.id
  referenced_security_group_id = aws_security_group.main_node.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
  description                  = "Flannel VXLAN from server nodes"
}

resource "aws_vpc_security_group_ingress_rule" "main_flannel_from_sub" {
  security_group_id            = aws_security_group.main_node.id
  referenced_security_group_id = aws_security_group.sub_node.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
  description                  = "Flannel VXLAN from shared worker nodes"
}

resource "aws_vpc_security_group_ingress_rule" "sub_flannel_from_main" {
  security_group_id            = aws_security_group.sub_node.id
  referenced_security_group_id = aws_security_group.main_node.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
  description                  = "Flannel VXLAN from server nodes"
}

resource "aws_vpc_security_group_ingress_rule" "sub_flannel_from_sub" {
  security_group_id            = aws_security_group.sub_node.id
  referenced_security_group_id = aws_security_group.sub_node.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
  description                  = "Flannel VXLAN from shared worker nodes"
}

resource "aws_vpc_security_group_ingress_rule" "main_kubelet_from_main" {
  security_group_id            = aws_security_group.main_node.id
  referenced_security_group_id = aws_security_group.main_node.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  description                  = "Kubelet from server nodes"
}

resource "aws_vpc_security_group_ingress_rule" "main_kubelet_from_sub" {
  security_group_id            = aws_security_group.main_node.id
  referenced_security_group_id = aws_security_group.sub_node.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  description                  = "Kubelet from shared worker nodes"
}

resource "aws_vpc_security_group_ingress_rule" "sub_kubelet_from_main" {
  security_group_id            = aws_security_group.sub_node.id
  referenced_security_group_id = aws_security_group.main_node.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  description                  = "Kubelet from server nodes"
}

resource "aws_vpc_security_group_ingress_rule" "sub_kubelet_from_sub" {
  security_group_id            = aws_security_group.sub_node.id
  referenced_security_group_id = aws_security_group.sub_node.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  description                  = "Kubelet from shared worker nodes"
}

resource "aws_vpc_security_group_egress_rule" "main_all_out" {
  security_group_id = aws_security_group.main_node.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound"
}

resource "aws_vpc_security_group_egress_rule" "sub_all_out" {
  security_group_id = aws_security_group.sub_node.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound"
}
