#!/bin/bash

# sudo apt-get -y update
# sudo apt-get -y install nginx

yum update -y
yum install httpd -y
systemctl start httpd
systemctl enable httpd
cd /var/www/html
echo "This is a very basic Web App to demo a HA architecture" > index.html

