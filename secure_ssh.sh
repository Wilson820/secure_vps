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

# Limpiar CUALQUIER configuración previa de Port y PermitRootLogin
# Esto elimina líneas como "Port 22", "#Port 22", "Port 2222", etc.
sudo sed -i "/^[# ]*Port /d" /etc/ssh/sshd_config
sudo sed -i "/^[# ]*PermitRootLogin /d" /etc/ssh/sshd_config

# Añadir la nueva configuración limpia
echo "Port $NUEVO_PUERTO" | sudo tee -a /etc/ssh/sshd_config > /dev/null
echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config > /dev/null

# 4. Actualizar Firewall UFW
echo "--- Actualizando Firewall ---"
sudo ufw allow $NUEVO_PUERTO/tcp
sudo ufw delete allow 22/tcp 2>/dev/null

# 5. Manejo de Sockets y Reinicio (Crítico para Ubuntu moderno)
echo "--- Asegurando persistencia y reiniciando servicio ---"

# Si existe ssh.socket, hay que desactivarlo para que ssh.service tome el control
if systemctl is-active --quiet ssh.socket || systemctl is-enabled --quiet ssh.socket; then
    echo "Desactivando ssh.socket para dar control total a ssh.service..."
    sudo systemctl stop ssh.socket
    sudo systemctl disable ssh.socket
    sudo systemctl mask ssh.socket
fi

# Validar sintaxis antes de reiniciar
echo "Validando sintaxis de configuración..."
sudo mkdir -p /run/sshd
if sudo /usr/sbin/sshd -t; then
    # Habilitar el servicio para que sea PERSISTENTE tras el reboot
    sudo systemctl enable ssh
    sudo systemctl restart ssh
    
    echo "--------------------------------------------------------"
    echo "¡SSH configurado exitosamente en el puerto $NUEVO_PUERTO!"
    echo "EL SERVICIO HA SIDO CONFIGURADO COMO PERSISTENTE (AUTO-START)."
    echo "IMPORTANTE: Prueba tu conexión en una nueva terminal:"
    echo "ssh -p $NUEVO_PUERTO $USUARIO@tu_ip_vps"
    echo "NO CIERRES ESTA SESIÓN HASTA ESTAR SEGURO."
    echo "--------------------------------------------------------"
else
    echo "FATAL: Error en la configuración de SSH. Restaurando backup..."
    sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
    sudo systemctl enable ssh
    sudo systemctl restart ssh
    echo "Se ha restaurado la configuración original para evitar pérdida de acceso."
fi
