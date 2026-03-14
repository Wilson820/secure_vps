#!/bin/bash
# setup_npm.sh - Despliegue de Nginx Proxy Manager

mkdir -p ~/nginx-proxy-manager
cd ~/nginx-proxy-manager

cat <<EOF > docker-compose.yml
version: '3.8'
services:
  app:
    image: 'jc21/nginx-proxy-manager:latest'
    restart: unless-stopped
    ports:
      - '80:80'
      - '81:81'
      - '443:443'
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
EOF

sudo docker-compose up -d

echo "-------------------------------------------------------"
echo "Nginx Proxy Manager está listo."
echo "Accede a: http://tu_ip_del_vps:81"
echo "Usuario inicial: admin@example.com"
echo "Password inicial: changeme"
echo "-------------------------------------------------------"
