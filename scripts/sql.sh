#! /bin/bash
apt update
apt install docker.io -y
docker run -d -e MYSQL_ROOT_PASSWORD=pasword -p 3306:3306 mysql 
