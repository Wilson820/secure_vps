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
sudo ufw --force enable

echo "--- Configurando fail2ban ---"
# Sin jail.local, fail2ban se instala pero no protege nada. secure_ssh.sh
# actualiza el puerto de aquí automáticamente al cambiar el puerto de SSH.
sudo tee /etc/fail2ban/jail.local > /dev/null <<'EOF'
[sshd]
enabled  = true
port     = 22
backend  = systemd
maxretry = 5
findtime = 10m
bantime  = 1h
EOF
sudo systemctl enable --now fail2ban

echo "Instalación completada. Reinicia el sistema si es necesario."
