 
region = "eu-west-1"

namespace = "gmb"

stage = "demo"

name = "ec2-instance"

availability_zones = ["eu-west-1a", "eu-west-1b"]

assign_eip_address = false

associate_public_ip_address = true

instance_type = "t2.micro"

allowed_ports = [22, 80]
