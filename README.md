# HA-infra

This repo contains a HA infrastructure provisioned with Terraform along with a user-data file. The Terraform creates an infra that is similar to the AWS implementation below.

![HA-architecture](https://github.com/WG17mn/HA-infra/blob/main/HA-arch.PNG)

Due to some technical issues faced with the ansible deployment implementation, I've limited the architecture to use a user-data for demo purposes. Instead, the instance creation and app deployment will be automated using AWS auto-scaling feature.

However, future work would include a web app deployed through Ansible playbook. Additionally, Docker could be used to package the app and remove dependencies related issues.

## Tools used
 - AWS;
 - Terraform;
 - ~~Ansible~~ user-data file(deployment.sh);

## Launch Instructions
terraform init

terraform plan

terraform apply

curl -X GET load-balancer-dns-name
