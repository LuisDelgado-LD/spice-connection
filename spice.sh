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

# Función para obtener el listado de todas las vms del nodo (id y nombre)
get_full_list_of_vms(){
    local ticket="$1"
    local csrf="$2"
    local proxy="$3"
    local host="$4"
    local port="$5"
    curl -f -s -S -k \
        -b "PVEAuthCookie=$ticket" \
        -H "CSRFPreventionToken: $csrf" \
        "https://$proxy:$port/api2/json/nodes/$host/qemu/" | \
        grep -o '{[^}]*}' | while read -r vm; do
            vmid=$(echo "$vm" | grep -o '"vmid":[0-9]*' | grep -o '[0-9]*')
            name=$(echo "$vm" | grep -o '"name":"[^"]*"' | sed 's/"name":"\(.*\)"/\1/')
            if [[ -n "$vmid" ]]; then
                echo "$vmid $name"
            fi
        done
}

# Función para filtrar e imprimir solo las VMs que soportan SPICE (id y nombre)
filter_spice_vms(){
    set +e  # Deshabilitar set -e temporalmente
    local ticket="$1"
    local csrf="$2"
    local proxy="$3"
    local host="$4"
    local port="$5"
    local vms_list
    vms_list=$(get_full_list_of_vms "$ticket" "$csrf" "$proxy" "$host" "$port")
    while IFS= read -r line; do
        vmid=$(echo "$line" | awk '{print $1}')
        name=$(echo "$line" | cut -d' ' -f2-)
        # Consultar la configuración de la VM
        config=$(curl -f -s -S -k \
            -b "PVEAuthCookie=$ticket" \
            -H "CSRFPreventionToken: $csrf" \
            "https://$proxy:$port/api2/json/nodes/$host/qemu/$vmid/config")
        spice_enabled=$(echo "$config" | grep -oE '"vga":"[^"]*"' | grep -E '.*(qxl[0-9]*|virtio|virtio-gl).*')
        if [[ -n "$spice_enabled" ]]; then
            echo "ID: $vmid | Nombre: $name"
        fi
    done <<< "$vms_list"
    set -e  # Rehabilitar set -e
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

# Inicialización de variables principales
USERNAME="$DEFAULT_USERNAME"
VMID="$1"
HOST="${2:-$DEFAULT_HOST}"
PROXY="${3:-${DEFAULT_PROXY:-$HOST}}"
HOST="${HOST%%\.*}"



# Procesar argumentos
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
    echo "No se especificó un ID de VM. Mostrando VMs compatibles con SPICE:"
    PASSWORD=$(get_password "$USERNAME")
    echo "Autenticando..."
    AUTH_DATA=$(get_auth_ticket "$USERNAME" "$PASSWORD" "$PROXY" "$DEFAULT_PORT")
    TICKET=$(parse_auth_data "$AUTH_DATA" "ticket")
    CSRF=$(parse_auth_data "$AUTH_DATA" "csrf")
    if [[ -z "$TICKET" || -z "$CSRF" ]]; then
        echo "Error: Fallo en la autenticación" >&2
        exit 1
    fi
    echo "Autenticación exitosa"
    filter_spice_vms "$TICKET" "$CSRF" "$PROXY" "$HOST" "$DEFAULT_PORT"
    
    # Solicitar al usuario que elija una VM
    echo
    read -p "Ingrese el ID de la VM a la que desea conectar (o presione Enter para salir): " selected_vmid
    
    if [[ -z "$selected_vmid" ]]; then
        echo "Operación cancelada."
        exit 0
    fi
    
    # Validar que el ID sea numérico
    if ! [[ "$selected_vmid" =~ ^[0-9]+$ ]]; then
        echo "Error: El ID de la VM debe ser un número." >&2
        exit 1
    fi
    
    # Asignar el ID seleccionado y continuar con la conexión
    VMID="$selected_vmid"
    echo "Conectando a la VM $VMID..."
else
    VMID="$1"
fi

# Configurar variables
HOST="${DEFAULT_HOST:-$2}"
# Si se especificó un proxy en línea de comandos, úsalo
# Si no, usa PROXMOX_PROXY del archivo de configuración
# Si tampoco existe, usa el HOST
PROXY="${3:-${DEFAULT_PROXY:-$HOST}}"
HOST="${HOST%%\.*}"

# Obtener contraseña de forma segura (solo si no se obtuvo antes)
if [[ -z "$PASSWORD" ]]; then
    PASSWORD=$(get_password "$USERNAME")
fi

# Obtener y procesar la autenticación (solo si no se obtuvo antes)
if [[ -z "$TICKET" || -z "$CSRF" ]]; then
    echo "Autenticando..."
    AUTH_DATA=$(get_auth_ticket "$USERNAME" "$PASSWORD" "$PROXY" "$DEFAULT_PORT")
    TICKET=$(parse_auth_data "$AUTH_DATA" "ticket")
    CSRF=$(parse_auth_data "$AUTH_DATA" "csrf")

    if [[ -z "$TICKET" || -z "$CSRF" ]]; then
        echo "Error: Fallo en la autenticación" >&2
        exit 1
    fi
    echo "Autenticación exitosa"
fi

# Obtener configuración SPICE y conectar
echo "Obteniendo configuración SPICE..."
get_spice_config "$TICKET" "$CSRF" "$PROXY" "$HOST" "$VMID" "$DEFAULT_PORT"

echo "Iniciando visor SPICE..."
exec remote-viewer spiceproxy &