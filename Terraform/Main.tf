provider "aws" {
  profile = "default"
  region = "${var.aws_region}"
}

# VPC and InternetGateway-
module "VPC" {
  source = "./Network/VPC"
}

# Subnets
module "PublicSubnet" {
  source = "./Network/Subnet"
  vpc_id = "${module.VPC.VPC_ID}"
  subnet_cidr = "10.0.0.0/24"
  subnet_name = "Public-Subnet"
}

module "PrivateSubnet1" {
  source = "./Network/Subnet"
  vpc_id = "${module.VPC.VPC_ID}"
  subnet_cidr = "10.0.1.0/24"
  subnet_name = "Private-Subnet1"
}

module "PrivateSubnet2" {
  source = "./Network/Subnet"
  vpc_id = "${module.VPC.VPC_ID}"
  subnet_cidr = "10.0.1.128/24"
  subnet_name = "Private-Subnet2"
}

resource "aws_eip" "NAT-EIP" {}     #Elastic IP for Nat Gateway

module "NATGateway" {
  source = "./Network/NATGateway"
  elasticIPID = "${aws_eip.NAT-EIP.id}"
  subnet_id = "${module.PublicSubnet.subnet_id}"
}

# --Route Tables
module "PublicRouteTable" {
  source = "./Network/RouteTable"
  vpc_id = "${module.VPC.VPC_ID}"
  gateway_id = "${module.VPC.IG_ID}"
  RouteTableName = "PublicRouteTable"
}

module "PrivateRouteTable" {
  source = "./Network/RouteTable"
  vpc_id = "${module.VPC.VPC_ID}"
  gateway_id = "${module.NATGateway.NATGateway_id}"
  RouteTableName = "PublicRouteTable"
}

module "PublicSubnetRoute" {
  source = "./Network/Route"
  route_table_id = "${module.PublicRouteTable.route_table_id}"
  gateway_id = "${module.VPC.IG_ID}"
  is_to_nat = false
}

module "PrivateSubnetRoute" {
  source = "./Network/Route"
  route_table_id = "${module.PrivateRouteTable.route_table_id}"
  nat_gateway_id = "${module.NATGateway.NATGateway_id}"
  is_to_nat = true
}

module "PublicRouteTableAssociation" {
  source = "./Network/RouteTableAssociation"
  subnet_id = "${module.PublicSubnet.subnet_id}"
  route_table_id = "${module.PublicRouteTable.route_table_id}"
}

module "PrivateRouteTableAssociation1" {
  source = "./Network/RouteTableAssociation"
  subnet_id = "${module.PrivateSubnet1.subnet_id}"
  route_table_id = "${module.PrivateRouteTable.route_table_id}"
}

module "PrivateRouteTableAssociation2" {
  source = "./Network/RouteTableAssociation"
  subnet_id = "${module.PrivateSubnet2.subnet_id}"
  route_table_id = "${module.PrivateRouteTable.route_table_id}"
}

# Security Group
module "PublicEC2SecurityGroup" {
  source = "./Network/SecurityGroup"
  vpc_id = "${module.VPC.VPC_ID}"
}

module "PrivateEC2SecurityGroup" {
  source = "./Network/SecurityGroup"
  vpc_id = "${module.VPC.VPC_ID}"
}

module "RDSSecurityGroup" {
  source = "./Network/SecurityGroup"
  vpc_id = "${module.VPC.VPC_ID}"
}


# Ingress rule for public EC2 allows SSH from Eureka IP Addresses
module "public_ec2_sg_ingress_ssh" {
  source = "./Network/SecurityGroupRule"
  is_cidr_source = false
  type = "ingress"
  security_group_id = "${module.PublicEC2SecurityGroup.security_group_id}"
  cidr_blocks = ["59.152.53.168/30", "59.152.53.104/29", "59.152.53.200/29", "59.152.53.120/29"]
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
}

# Egress rule for public EC2 which only allows HTTP for package updates
module "public_ec2_sg_egress_http" {
  source = "./Network/SecurityGroupRule"
  is_cidr_source = true
  type = "egress"
  security_group_id = "${module.PublicEC2SecurityGroup.security_group_id}"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

# Egress rule for public EC2 which only allows HTTPS for package updates
module "public_ec2_sg_egress_https" {
  source = "./Network/SecurityGroupRule"
  is_cidr_source = true
  type = "egress"
  security_group_id = "${module.PublicEC2SecurityGroup.security_group_id}"
  from_port = 443
  to_port = 443
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

# Ingress rule for private EC2 which only allows SSH from public ec2 instance
module "private_ec2_sg_ingress_ssh" {
  source = "./Network/SecurityGroupRule"
  is_cidr_source = false
  type = "ingress"
  security_group_id = "${module.PrivateEC2SecurityGroup.security_group_id}"
  source_security_group_id = "${module.PublicEC2SecurityGroup.security_group_id}"
  from_port = 22
  to_port = 22
  protocol = "tcp"
}

# Egress rule for private EC2 which only allows HTTP for package updates
module "private_ec2_sg_egress_http" {
  source = "./Network/SecurityGroupRule"
  is_cidr_source = true
  type = "egress"
  security_group_id = "${module.PrivateEC2SecurityGroup.security_group_id}"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

# Egress rule for private EC2 which only allows HTTPS for package updates
module "private_ec2_sg_egress_https" {
  source = "./Network/SecurityGroupRule"
  is_cidr_source   = true
  type = "egress"
  security_group_id = "${module.PrivateEC2SecurityGroup.security_group_id}"
  from_port = 443
  to_port = 443
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

# Egress rule for private EC2 which allows MySQL connection with private RDS instance
module "private_ec2_sg_egress_rds" {
  source = "./Network/SecurityGroupRule"
  is_cidr_source = false
  type = "egress"
  security_group_id = "${module.PrivateEC2SecurityGroup.security_group_id}"
  from_port = 3306
  to_port = 3306
  protocol = "tcp"
  source_security_group_id = "${module.RDSSecurityGroup.security_group_id}"
}

# Ingress rule for private RDS which only allows connection from private ec2 instance
module "rds_sg_ingress" {
  source = "./Network/SecurityGroupRule"
  is_cidr_source = false
  type = "ingress"
  security_group_id = "${module.RDSSecurityGroup.security_group_id}"
  source_security_group_id = "${module.PrivateEC2SecurityGroup.security_group_id}"
  from_port = 3306
  to_port = 3306
  protocol = "tcp"
}

# Egress rule for private RDS which only allows HTTP for package updates
module "rds_sg_egress_http" {
  source = "./Network/SecurityGroupRule"
  is_cidr_source = true
  type = "egress"
  security_group_id = "${module.RDSSecurityGroup.security_group_id}"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

# Egress rule for private RDS which only allows HTTPS for package updates
module "rds_sg_egress_2" {
  source = "./Network/SecurityGroupRule"
  is_cidr_source = true
  type = "egress"
  security_group_id = "${module.RDSSecurityGroup.security_group_id}"
  from_port = 443
  to_port = 443
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

# Public EC2 instance
module "public_ec2" {
  source    = "./EC2"
  key_name  = "krutik-vir"
  vpc_security_group_ids = "${module.PublicEC2SecurityGroup.security_group_id}"
  subnet_id = "${var.PublicSubnet.id}"
}

# Private EC2 instance
module "private_ec2" {
  source    = "./EC2"
  key_name  = "krutik-vir"
  vpc_security_group_ids = "${module.PrivateEC2SecurityGroup.security_group_id}"
  subnet_id = "${var.PrivateSubnet1.id}"

  user_data = <<EOF
    #!/bin/bash
    yum update -y
    echo "starting installation" >> start-up.log
    yum install mysql-server -y
    echo "installed" >> start-up.log
    /sbin/service mysqld start
    mysqladmin -u root password 'toor'
    RDS_MYSQL_ENDPOINT="${element(split(":", aws_db_instance.krutik_RDS.endpoint), 0)}";
    RDS_MYSQL_USER="krutik";
    RDS_MYSQL_PASS="pass@123";
    RDS_MYSQL_BASE="krutik-db";
    mysql -h $RDS_MYSQL_ENDPOINT -u $RDS_MYSQL_USER -p$RDS_MYSQL_PASS -D $RDS_MYSQL_BASE -e 'quit';
    if [[ $? -eq 0 ]]; then
      echo "MySQL connection: OK" >> conn;
      mysql -h $RDS_MYSQL_ENDPOINT -u $RDS_MYSQL_USER -p$RDS_MYSQL_PASS -D $RDS_MYSQL_BASE --execute='CREATE TABLE krutik1( id INT)';
      echo "MySQL table create" >> conn;
      mysql -h $RDS_MYSQL_ENDPOINT -u $RDS_MYSQL_USER -p$RDS_MYSQL_PASS -D $RDS_MYSQL_BASE --execute='INSERT into krutik1 (id) VALUES (1)';
      echo "MySQL insert" >> conn;
      mysql -h $RDS_MYSQL_ENDPOINT -u $RDS_MYSQL_USER -p$RDS_MYSQL_PASS -D $RDS_MYSQL_BASE --execute='SELECT * from krutik1' >> conn;
      echo "MySQL select" >> conn;
    else
      echo "MySQL connection: Fail" >> conn;
    fi;
    EOF
}

# RDS
module "krutik_RDS" {
  source = "./RDS"
  db_name = "krutik-db"
  db_username = "krutik"
  db_password = var.db_password
  vpc_sg_ids = ["${module.RDSSecurityGroup.security_group_id}"]
  subnet_group_name = "krutik_subnet_group"
  subnet_ids = [module.PrivateSubnet1.subnet_id, module.PrivateSubnet2.subnet_id]
}
