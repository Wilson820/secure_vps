#!/bin/bash
# secure_ssh.sh - Cambiar puerto SSH y endurecer acceso

# 1. Definir variables
NUEVO_PUERTO=2287  # Puedes cambiar este número (rango 1024-65535)
USUARIO="admin"    # Nombre del usuario que tendrá permisos root (sudo)

# 2. Crear el usuario y dar permisos root si no existe
if ! id "$USUARIO" &>/dev/null; then
    echo "--- Creando usuario: $USUARIO ---"
    sudo adduser --gecos "" "$USUARIO"
    
    # Intentar añadir a grupo sudo (Debian/Ubuntu) o wheel (CentOS/Arch)
    if grep -q "^sudo:" /etc/group; then
        sudo usermod -aG sudo "$USUARIO"
    elif grep -q "^wheel:" /etc/group; then
        sudo usermod -aG wheel "$USUARIO"
    fi
    echo "Usuario $USUARIO creado y añadido al grupo de superusuario."
else
    echo "--- El usuario $USUARIO ya existe. Verificando permisos ---"
    if grep -q "^sudo:" /etc/group; then
        sudo usermod -aG sudo "$USUARIO"
    elif grep -q "^wheel:" /etc/group; then
        sudo usermod -aG wheel "$USUARIO"
    fi
fi

# 3. Configuración de SSH

echo "--- Configurando SSH en puerto $NUEVO_PUERTO ---"

# Hacer backup de la configuración original
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Modificar el puerto y deshabilitar login de root por contraseña
sudo sed -i "s/#Port 22/Port $NUEVO_PUERTO/" /etc/ssh/sshd_config
sudo sed -i "s/Port 22/Port $NUEVO_PUERTO/" /etc/ssh/sshd_config
sudo sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config
sudo sed -i "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config

# 4. Actualizar Firewall UFW
echo "--- Actualizando Firewall ---"
sudo ufw allow $NUEVO_PUERTO/tcp
sudo ufw delete allow 22/tcp

# 5. Reiniciar servicio
sudo systemctl restart ssh

echo "--------------------------------------------------------"
echo "¡SSH configurado en el puerto $NUEVO_PUERTO!"
echo "IMPORTANTE: Prueba tu conexión en una nueva terminal:"
echo "ssh -p $NUEVO_PUERTO $USUARIO@tu_ip_vps"
echo "NO CIERRES ESTA SESIÓN HASTA ESTAR SEGURO."
echo "--------------------------------------------------------"
