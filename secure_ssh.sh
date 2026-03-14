#!/bin/bash
# secure_ssh.sh - Cambiar puerto SSH y endurecer acceso

echo "--- WARNING ---"
echo "Nota importante: Antes de ejecutarlo, asegúrate de tener un usuario creado con permisos de sudo. No cierres tu sesión actual hasta que confirmes que puedes entrar por el nuevo puerto"

NUEVO_PUERTO=2287  # Puedes cambiar este número (rango 1024-65535)
USUARIO=$(whoami)

echo "--- Configurando SSH en puerto $NUEVO_PUERTO ---"

# 1. Hacer backup de la configuración original
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# 2. Modificar el puerto y deshabilitar login de root por contraseña
sudo sed -i "s/#Port 22/Port $NUEVO_PUERTO/" /etc/ssh/sshd_config
sudo sed -i "s/Port 22/Port $NUEVO_PUERTO/" /etc/ssh/sshd_config
sudo sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config
sudo sed -i "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config

# 3. Actualizar Firewall UFW
echo "--- Actualizando Firewall ---"
sudo ufw allow $NUEVO_PUERTO/tcp
sudo ufw delete allow 22/tcp

# 4. Reiniciar servicio
sudo systemctl restart ssh

echo "--------------------------------------------------------"
echo "¡SSH configurado en el puerto $NUEVO_PUERTO!"
echo "IMPORTANTE: Prueba tu conexión en una nueva terminal:"
echo "ssh -p $NUEVO_PUERTO $USUARIO@tu_ip_vps"
echo "NO CIERRES ESTA SESIÓN HASTA ESTAR SEGURO."
echo "--------------------------------------------------------"
