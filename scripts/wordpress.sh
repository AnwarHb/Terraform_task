#! /bin/bash
apt update
apt install docker.io -y
docker run -d -p 80:80 wordpress