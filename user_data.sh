#!/bin/bash
apt update
apt install nginx
echo "<h1>Hello from $HOSTNAME</h1>" > /var/www/html/index.html
systemctl restart nginx