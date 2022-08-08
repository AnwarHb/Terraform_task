# Terraform_task

In this repository, i used Terraform to create the following enviroment:
- VPC
- 2 Subnets: a public and a private subnet
- Internet Gateway
- NAT Gateway
- Route Tables - one foreach subnet
- Route Tables Associations
- an instance with WordPress installed on the public subnet
- an instance with MySQL installed on the private subnet

docker was used to run mySQL and wordPress.

#### Build the enviroment:
- First, connect your terraform workspaces to your AWS account.you could export your AWS access and secret keys with:
 `export AWS_ACCESS_KEY_ID=<access-key>`
 `export AWS_SECRET_ACCESS_KEY=<your-secret-key>`
- Initialize a working directory containing Terraform configuration files with the command:
 `terraform init`
- You could review the terraform plan befoure building:
 `terraform plan`
- Apply the configuration file:
 `terraform apply`
In your AWS Console you can see 2 running instances:
[![](https://github.com/AnwarHb/Terraform_task/blob/main/servers-running.png?raw=true)](https://github.com/AnwarHb/Terraform_task/blob/main/servers-running.png?raw=true)


#### Connect  to instances:
The public server will function as a jumb server, requests for the private instance will first reach the public server and the public server will connect to the private server.

- transfer your generated key to the public server:
 `scp -i newSSHkey.pem newSSHkey.pem ubuntu@<IP-wordpress>:~/`
- ssh to the public server:
 `ssh -i newSSHkey.pem ubuntu@<IP-wordpress>`
- ssh to the private server:
 `chmod 400 newSSHkey.pem`
 `ssh -i newSSHkey.pem ubuntu@<IP-mySql>`
