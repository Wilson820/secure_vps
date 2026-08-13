#!/bin/bash
# secure_ssh.sh - Cambiar puerto SSH y endurecer acceso, sin riesgo de quedarse fuera.
#
# Funciona en DOS FASES:
#   Fase 1 (reversible): sshd escucha en 22 Y en el puerto nuevo a la vez.
#   Fase 2 (definitiva): solo tras confirmar TU que has entrado por el puerto nuevo,
#                        se cierra el 22 y se desactiva el login de root.
#
# Variables de entorno opcionales: SSH_PORT, SSH_USER
#   SSH_PORT=2222 SSH_USER=wilson ./secure_ssh.sh

set -euo pipefail

# 1. Definir variables
NUEVO_PUERTO="${SSH_PORT:-2287}"   # Puedes cambiar este número (rango 1024-65535)
USUARIO="${SSH_USER:-admon}"       # Nombre del usuario que tendrá permisos root (sudo)

SSHD_CONFIG="/etc/ssh/sshd_config"
DROPIN_DIR="/etc/ssh/sshd_config.d"
# El prefijo 00- es intencionado: OpenSSH aplica "el primer valor gana" y los drop-ins
# se leen en orden alfabético, así que 00- gana a 50-cloud-init.conf.
DROPIN="$DROPIN_DIR/00-secure-vps.conf"
BACKUP="/etc/ssh/sshd_config.$(date +%Y%m%d-%H%M%S).bak"

SOCKET_ENMASCARADO=0   # 1 si este script enmascaró ssh.socket
ESTADO="inicial"       # inicial -> fase1 -> ok

if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

msg()   { echo "--- $* ---"; }
fatal() { echo "ERROR: $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Utilidades de verificación
# ---------------------------------------------------------------------------

# Configuración EFECTIVA de sshd (resuelve los Include de sshd_config.d).
# Imprescindible: "sshd -t" solo valida sintaxis y da falsos positivos.
sshd_efectivo() {
    $SUDO /usr/sbin/sshd -T -C "user=$USUARIO,host=localhost,addr=127.0.0.1" 2>/dev/null
}

puerto_en_uso() {
    ss -lnt 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${1}\$"
}

# Tras un restart sshd tarda un instante en enlazar el socket.
puerto_escuchando() {
    local intento
    for intento in 1 2 3 4 5; do
        puerto_en_uso "$1" && return 0
        sleep 1
    done
    return 1
}

# Segundo campo de "passwd -S": P = contraseña utilizable, L = bloqueada, NP = sin contraseña.
estado_password() {
    $SUDO passwd -S "$USUARIO" 2>/dev/null | awk '{print $2}'
}

grupo_sudo() {
    if grep -q "^sudo:" /etc/group; then
        echo "sudo"
    elif grep -q "^wheel:" /etc/group; then
        echo "wheel"
    fi
}

# ---------------------------------------------------------------------------
# Reversión
# ---------------------------------------------------------------------------

revertir_todo() {
    set +e
    echo
    msg "Revirtiendo la configuración de SSH al estado original"

    $SUDO rm -f "$DROPIN"
    [ -f "$BACKUP" ] && $SUDO cp "$BACKUP" "$SSHD_CONFIG"

    if [ "$SOCKET_ENMASCARADO" -eq 1 ]; then
        # Devolvemos el control a ssh.socket tal y como estaba antes.
        $SUDO systemctl stop ssh
        $SUDO systemctl unmask ssh.socket
        $SUDO systemctl daemon-reload
        $SUDO systemctl enable --now ssh.socket
        SOCKET_ENMASCARADO=0
    else
        $SUDO systemctl restart ssh
    fi

    echo "Configuración restaurada al estado previo a ejecutar este script."
    echo "Backup utilizado: $BACKUP"
    echo "Puertos SSH activos ahora: $(sshd_efectivo | awk '$1=="port"{print $2}' | tr '\n' ' ')"
    set -e
}

limpieza_final() {
    local codigo=$?
    trap - EXIT
    if [ "$ESTADO" != "ok" ] && [ "$ESTADO" != "inicial" ]; then
        echo
        echo "El script terminó de forma inesperada (código $codigo)."
        revertir_todo
    fi
    exit "$codigo"
}
trap limpieza_final EXIT

# ---------------------------------------------------------------------------
# 2. Comprobaciones previas (nada se toca hasta que todas pasen)
# ---------------------------------------------------------------------------

[ -t 0 ] || fatal "Este script necesita una terminal interactiva (crea el usuario y pide confirmación).
No lo ejecutes con 'curl | bash' ni redirigiendo la entrada. Usa: ./secure_ssh.sh"

if [ -n "$SUDO" ] && ! sudo -n true 2>/dev/null; then
    sudo -v || fatal "Se necesitan privilegios de root (sudo)."
fi

case "$NUEVO_PUERTO" in
    ''|*[!0-9]*) fatal "SSH_PORT no es un número: $NUEVO_PUERTO" ;;
esac
if [ "$NUEVO_PUERTO" -lt 1024 ] || [ "$NUEVO_PUERTO" -gt 65535 ]; then
    fatal "El puerto debe estar entre 1024 y 65535 (recibido: $NUEVO_PUERTO)."
fi
# Si el puerto ya está ocupado pero es el propio sshd (re-ejecución del script), no pasa nada.
if puerto_en_uso "$NUEVO_PUERTO" && ! sshd_efectivo | grep -qx "port $NUEVO_PUERTO"; then
    fatal "El puerto $NUEVO_PUERTO ya está ocupado por otro proceso. Elige otro con SSH_PORT=..."
fi

# ---------------------------------------------------------------------------
# 3. Crear el usuario y VERIFICAR que puede entrar antes de tocar nada
# ---------------------------------------------------------------------------

if ! id "$USUARIO" &>/dev/null; then
    msg "Creando usuario: $USUARIO"
    # Si ya existe un grupo con ese nombre (grupo legacy de la distro o resto de un
    # intento anterior), adduser aborta al intentar crearlo. Se reutiliza con --ingroup.
    if getent group "$USUARIO" >/dev/null; then
        echo "El grupo $USUARIO ya existe; se reutilizará como grupo primario."
        $SUDO adduser --gecos "" --ingroup "$USUARIO" "$USUARIO" \
            || fatal "La creación del usuario $USUARIO falló o se canceló. No se ha modificado SSH."
    else
        $SUDO adduser --gecos "" "$USUARIO" \
            || fatal "La creación del usuario $USUARIO falló o se canceló. No se ha modificado SSH."
    fi
else
    msg "El usuario $USUARIO ya existe. Verificando permisos"
fi

GRUPO="$(grupo_sudo)"
[ -n "$GRUPO" ] || fatal "No existe el grupo 'sudo' ni 'wheel' en este sistema."
$SUDO usermod -aG "$GRUPO" "$USUARIO"

if ! id -nG "$USUARIO" | tr ' ' '\n' | grep -qx "$GRUPO"; then
    fatal "No se pudo añadir $USUARIO al grupo $GRUPO."
fi
echo "Usuario $USUARIO en el grupo de superusuario ($GRUPO)."

# Este es el fallo que dejaba el VPS inaccesible: si adduser se cancela, la cuenta
# queda sin contraseña utilizable y luego se desactivaba el login de root igualmente.
msg "Comprobando que $USUARIO tiene una contraseña utilizable"
intentos=0
while [ "$(estado_password)" != "P" ]; do
    intentos=$((intentos + 1))
    if [ "$intentos" -gt 3 ]; then
        fatal "$USUARIO sigue sin contraseña utilizable. No se ha modificado SSH."
    fi
    echo "La cuenta $USUARIO no tiene contraseña utilizable. Establécela ahora (intento $intentos/3):"
    $SUDO passwd "$USUARIO" || true
done
echo "OK: $USUARIO tiene contraseña utilizable."

# ---------------------------------------------------------------------------
# 4. FASE 1 - escuchar en 22 y en el puerto nuevo al mismo tiempo
# ---------------------------------------------------------------------------

msg "FASE 1: añadiendo el puerto $NUEVO_PUERTO (el 22 sigue abierto)"

$SUDO cp "$SSHD_CONFIG" "$BACKUP"
echo "Backup de la configuración actual: $BACKUP"

$SUDO mkdir -p "$DROPIN_DIR"

# ¿Lee sshd los drop-ins? En Ubuntu >= 20.04 sí; en Debian antiguo hay que añadir el Include.
USAR_DROPIN=1
if ! grep -qE '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf' "$SSHD_CONFIG"; then
    echo "El fichero principal no incluye $DROPIN_DIR; intentando añadir el Include..."
    $SUDO sed -i "1i Include $DROPIN_DIR/*.conf" "$SSHD_CONFIG"
    $SUDO mkdir -p /run/sshd
    if ! $SUDO /usr/sbin/sshd -t 2>/dev/null; then
        echo "Esta versión de OpenSSH no soporta Include; se escribirá en $SSHD_CONFIG."
        $SUDO cp "$BACKUP" "$SSHD_CONFIG"
        USAR_DROPIN=0
    fi
fi

ESTADO="fase1"

escribir_config() {
    # $1 = bloque de configuración
    if [ "$USAR_DROPIN" -eq 1 ]; then
        printf '%s\n' "$1" | $SUDO tee "$DROPIN" > /dev/null
        $SUDO chmod 644 "$DROPIN"
    else
        printf '%s\n' "$1" | $SUDO tee -a "$SSHD_CONFIG" > /dev/null
    fi
}

# "Port" es acumulativo en OpenSSH (no gana el primero: se suman), así que hay que
# eliminar cualquier otro Port/ListenAddress o el 22 seguiría abierto en la fase 2.
limpiar_puertos_ajenos() {
    $SUDO sed -i -E '/^[[:space:]]*#?[[:space:]]*(Port|ListenAddress)[[:space:]]/d' "$SSHD_CONFIG"
    local f
    for f in "$DROPIN_DIR"/*.conf; do
        [ -e "$f" ] || continue
        [ "$f" = "$DROPIN" ] && continue
        $SUDO sed -i -E 's/^[[:space:]]*(Port|ListenAddress)[[:space:]]/#&/' "$f"
    done
}

CONFIG_FASE1="# Generado por secure_ssh.sh - FASE 1 (transitoria, el puerto 22 sigue activo)
Port 22
Port $NUEVO_PUERTO
PasswordAuthentication yes
PubkeyAuthentication yes"

limpiar_puertos_ajenos
escribir_config "$CONFIG_FASE1"

# En Ubuntu moderno el puerto lo manda ssh.socket, no sshd_config.
if systemctl is-active --quiet ssh.socket || systemctl is-enabled --quiet ssh.socket; then
    msg "Desactivando ssh.socket para dar control total a ssh.service"
    $SUDO systemctl stop ssh.socket
    $SUDO systemctl disable ssh.socket
    $SUDO systemctl mask ssh.socket
    $SUDO systemctl daemon-reload
    SOCKET_ENMASCARADO=1
fi

aplicar_y_verificar() {
    # $1 = lista de puertos esperados (separados por espacios)
    local esperados="$1" p

    $SUDO mkdir -p /run/sshd
    $SUDO /usr/sbin/sshd -t || { echo "Sintaxis de sshd_config inválida."; return 1; }

    local efectiva puertos
    efectiva="$(sshd_efectivo)" || { echo "No se pudo leer la configuración efectiva."; return 1; }
    puertos="$(echo "$efectiva" | awk '$1=="port"{print $2}' | sort -n | tr '\n' ' ')"
    puertos="${puertos% }"

    if [ "$puertos" != "$esperados" ]; then
        echo "La configuración EFECTIVA de sshd escucha en '$puertos' y se esperaba '$esperados'."
        echo "Probablemente otro fichero de $DROPIN_DIR lo está sobrescribiendo."
        return 1
    fi

    $SUDO systemctl enable ssh > /dev/null 2>&1 || true
    $SUDO systemctl restart ssh || { echo "ssh.service no arrancó."; return 1; }
    $SUDO systemctl is-active --quiet ssh || { echo "ssh.service no está activo."; return 1; }

    for p in $esperados; do
        puerto_escuchando "$p" || { echo "sshd no está escuchando en el puerto $p."; return 1; }
    done

    echo "Verificado: sshd activo y escuchando en $esperados."
    return 0
}

if ! aplicar_y_verificar "22 $NUEVO_PUERTO"; then
    revertir_todo
    ESTADO="ok"
    fatal "No se pudo activar el puerto $NUEVO_PUERTO. Nada ha cambiado, sigues entrando por el 22."
fi

msg "Actualizando Firewall (abrir $NUEVO_PUERTO, el 22 se cierra en la fase 2)"
if command -v ufw > /dev/null; then
    $SUDO ufw allow "$NUEVO_PUERTO"/tcp || true
else
    echo "ufw no está instalado; omitiendo el firewall."
fi

# ---------------------------------------------------------------------------
# 5. Puerto de no retorno: confirmación humana
# ---------------------------------------------------------------------------

cat <<EOF

========================================================
FASE 1 COMPLETADA. SSH escucha en el 22 Y en el $NUEVO_PUERTO.

NO CIERRES ESTA SESIÓN. Abre OTRA terminal y comprueba:

    ssh -p $NUEVO_PUERTO $USUARIO@<IP_DEL_VPS>
    sudo -v

Solo si has entrado y sudo funciona, escribe CONFIRMO aquí abajo.
Entonces se cerrará el puerto 22 y se desactivará el login de root.
Cualquier otra respuesta deja el servidor como estaba.
========================================================

EOF

read -r -p "Escribe CONFIRMO para continuar: " RESPUESTA
if [ "$RESPUESTA" != "CONFIRMO" ]; then
    revertir_todo
    ESTADO="ok"
    echo "Cancelado. Sigues entrando por el puerto 22 y como root, igual que antes."
    exit 0
fi

# ---------------------------------------------------------------------------
# 6. FASE 2 - cerrar el 22 y desactivar root
# ---------------------------------------------------------------------------

msg "FASE 2: dejando SSH solo en el puerto $NUEVO_PUERTO y desactivando el login de root"

CONFIG_FASE2="# Generado por secure_ssh.sh
Port $NUEVO_PUERTO
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes"

limpiar_puertos_ajenos
# En el modo sin drop-in la fase 1 quedó anexada al final: hay que quitarla antes.
if [ "$USAR_DROPIN" -eq 0 ]; then
    $SUDO sed -i -E '/^[[:space:]]*#?[[:space:]]*PermitRootLogin[[:space:]]/d' "$SSHD_CONFIG"
    $SUDO sed -i '/# Generado por secure_ssh.sh - FASE 1/,$d' "$SSHD_CONFIG"
fi
escribir_config "$CONFIG_FASE2"

if ! aplicar_y_verificar "$NUEVO_PUERTO"; then
    echo "Fallo al aplicar la fase 2. Volviendo a la fase 1 (puerto 22 abierto)."
    limpiar_puertos_ajenos
    escribir_config "$CONFIG_FASE1"
    aplicar_y_verificar "22 $NUEVO_PUERTO" || revertir_todo
    ESTADO="ok"
    fatal "No se pudo completar la fase 2. Conserva el acceso por el puerto 22."
fi

if sshd_efectivo | grep -q '^permitrootlogin no'; then
    echo "Verificado: PermitRootLogin no."
else
    echo "AVISO: PermitRootLogin no quedó aplicado; revisa $DROPIN_DIR."
fi

msg "Cerrando el puerto 22 en el firewall"
if command -v ufw > /dev/null; then
    # La regla del 22 puede existir en tres formas distintas.
    $SUDO ufw delete allow 22/tcp  > /dev/null 2>&1 || true
    $SUDO ufw delete allow 22      > /dev/null 2>&1 || true
    $SUDO ufw delete allow OpenSSH > /dev/null 2>&1 || true
    $SUDO ufw status | grep -E "^(22|OpenSSH)" && echo "AVISO: queda alguna regla del 22 sin borrar." || true
fi

if command -v fail2ban-client > /dev/null && [ -f /etc/fail2ban/jail.local ]; then
    $SUDO sed -i -E "s/^port[[:space:]]*=.*/port = $NUEVO_PUERTO/" /etc/fail2ban/jail.local
    $SUDO systemctl restart fail2ban || true
    echo "fail2ban actualizado al puerto $NUEVO_PUERTO."
fi

ESTADO="ok"

cat <<EOF

--------------------------------------------------------
¡SSH configurado exitosamente en el puerto $NUEVO_PUERTO!
El servicio queda habilitado para arrancar solo tras un reinicio.

Conecta siempre así:   ssh -p $NUEVO_PUERTO $USUARIO@<IP_DEL_VPS>

Root ya NO puede entrar por SSH. Usa sudo desde $USUARIO.
Backup de la configuración previa: $BACKUP
--------------------------------------------------------
EOF
