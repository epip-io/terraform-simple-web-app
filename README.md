# terraform-simple-web-app

## Requirements

Terraform ~> 0.12

## Initialize

```bash
terraform init
```

This is download the necessary parts for Terraform

## Deploy

```bash
terraform plan
```

This will create a VPC with subnets, an SSH key and an EC2 t2.miro instance. Inside the instance it will add 2 files - /opt/flaskapp/app.py and /etc/systemd/system/app.service.

It will ask for a local directory to save the SSH keys. At the end, it will print out the public URL. It maybe a min or two before it is avialable though.

## Clean up

```bash
terraform destory
```

This will remove everything that was created. It will ask to confirm, typing "yes" specifically when prompted will start the destruction process.
