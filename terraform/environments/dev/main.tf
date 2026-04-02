module "security_groups" {
  source = "../../modules/security-groups"

  name_prefix = var.name_prefix
  vpc_id      = var.vpc_id
  admin_cidr  = var.admin_cidr
}

