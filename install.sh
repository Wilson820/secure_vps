#!/bin/bash
# install.sh - Instalación de dependencias básicas y seguridad

echo "--- Actualizando sistema ---"
sudo apt update && sudo apt upgrade -y

echo "--- Instalando Docker y Docker Compose ---"
sudo apt install -y docker.io docker-compose
sudo systemctl enable --now docker

echo "--- Instalando herramientas de seguridad ---"
sudo apt install -y ufw fail2ban git

echo "--- Configurando Firewall básico ---"
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 81/tcp  # Puerto de administración de Nginx Proxy Manager
echo "y" | sudo ufw enable

echo "Instalación completada. Reinicia el sistema si es necesario."
