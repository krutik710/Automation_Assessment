output "vpc_id" {
  description = "VPC ID : "
  value = module.VPC.VPC_ID
}

output "public_ec2_ip" {
  description = "Public IP of public EC2 :"
  value = module.public_ec2.ec2_public_ip
}

output "private_ec2_ip" {
  description = "Private IP of private EC2 :"
  value = module.private_ec2.ec2_private_ip
}

output "rds_id" {
  description = "ID of RDS instance :"
  value = module.semil_RDS.rds_id
}
