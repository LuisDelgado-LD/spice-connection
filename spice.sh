#!/bin/bash

# Script para conectar a una VM de Proxmox usando SPICE
# Requiere pve-manager >= 3.1-44

set -e

# Configuración por defecto
DEFAULT_USERNAME='root@pam'
DEFAULT_HOST=''
DEFAULT_PORT='8006'
DEFAULT_PROXY=''  # Valor vacío por defecto, usará DEFAULT_HOST si no se especifica
CONFIG_FILE="${HOME}/.config/pve-spice/config"

# Cargar configuración desde archivo si existe
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "Cargando configuración desde $CONFIG_FILE"
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        
        # Asignar valores de configuración si existen
        DEFAULT_HOST="${DEFAULT_HOST:-$PROXMOX_HOST}"
        DEFAULT_PORT="${DEFAULT_PORT:-$PROXMOX_PORT}"
        DEFAULT_USERNAME="${DEFAULT_USERNAME:-$PROXMOX_USER}"
        DEFAULT_PROXY="${PROXMOX_PROXY:-$DEFAULT_PROXY}"
    fi
}

# Función para mostrar el uso del script
show_usage() { 
    echo "Uso: $0 [-u <usuario>] vmid [host [proxy]]"
    echo
    echo "Opciones:"
    echo "  -u <usuario>    Usuario para autenticación (default: $DEFAULT_USERNAME)"
    echo
    echo "Argumentos:"
    echo "  vmid           ID de la máquina virtual"
    echo "  host           Nombre del host Proxmox (default: $DEFAULT_HOST)"
    echo "  proxy          DNS o IP del proxy (default: igual que host)"
    echo
    echo "Nota: La configuración también puede ser definida en $CONFIG_FILE"
    exit 1
}

# Función para solicitar la contraseña de forma segura
get_password() {
    local password
    read -s -r -p "Ingrese la contraseña para $1: " password
    echo >&2
    printf '%s' "${password}"
}

# Función para obtener el ticket de autenticación
get_auth_ticket() {
    local username="$1"
    local password="$2"
    local proxy="$3"
    local port="$4"
    
    local data
    data="$(curl -f -s -S -k \
        --data-urlencode "username=$username" \
        --data-urlencode "password=$password" \
        "https://$proxy:$port/api2/json/access/ticket")"
    
    if [[ -z "$data" ]]; then
        echo "Error: No se pudo obtener el ticket de autenticación" >&2
        exit 1
    fi
    
    echo "$data"
}

# Función para extraer el ticket y token CSRF
parse_auth_data() {
    local data="$1"
    local field="$2"
    
    local value="${data//\"/}"
    case "$field" in
        "ticket")
            value="${value##*ticket:}"
            ;;
        "csrf")
            value="${value##*CSRFPreventionToken:}"
            ;;
    esac
    value="${value%%,*}"
    value="${value%%\}*}"
    
    echo "$value"
}

# Función para obtener la configuración SPICE
get_spice_config() {
    local ticket="$1"
    local csrf="$2"
    local proxy="$3"
    local host="$4"
    local vmid="$5"
    local port="$6"
    
    curl -f -s -S -k \
        -b "PVEAuthCookie=$ticket" \
        -H "CSRFPreventionToken: $csrf" \
        "https://$proxy:$port/api2/spiceconfig/nodes/$host/qemu/$vmid/spiceproxy" \
        -d "proxy=$proxy" > spiceproxy
}

# Cargar configuración si existe
load_config

# Procesar argumentos
USERNAME="$DEFAULT_USERNAME"

while getopts ":u:h" opt; do
    case $opt in
        u)
            USERNAME="$OPTARG"
            ;;
        h)
            show_usage
            ;;
        \?)
            echo "Opción inválida: -$OPTARG" >&2
            show_usage
            ;;
    esac
done

shift $((OPTIND-1))

# Validar argumentos
if [[ -z "$1" ]]; then
    echo "Error: Debe especificar el ID de la VM" >&2
    show_usage
fi

# Configurar variables
VMID="$1"
HOST="${DEFAULT_HOST:-$2}"
# Si se especificó un proxy en línea de comandos, úsalo
# Si no, usa PROXMOX_PROXY del archivo de configuración
# Si tampoco existe, usa el HOST
PROXY="${3:-${DEFAULT_PROXY:-$HOST}}"
HOST="${HOST%%\.*}"

# Obtener contraseña de forma segura
PASSWORD=$(get_password "$USERNAME")

# Obtener y procesar la autenticación
echo "Autenticando..."
AUTH_DATA=$(get_auth_ticket "$USERNAME" "$PASSWORD" "$PROXY" "$DEFAULT_PORT")
TICKET=$(parse_auth_data "$AUTH_DATA" "ticket")
CSRF=$(parse_auth_data "$AUTH_DATA" "csrf")

if [[ -z "$TICKET" || -z "$CSRF" ]]; then
    echo "Error: Fallo en la autenticación" >&2
    exit 1
fi

echo "Autenticación exitosa"

# Obtener configuración SPICE y conectar
echo "Obteniendo configuración SPICE..."
get_spice_config "$TICKET" "$CSRF" "$PROXY" "$HOST" "$VMID" "$DEFAULT_PORT"

echo "Iniciando visor SPICE..."
exec remote-viewer spiceproxy &