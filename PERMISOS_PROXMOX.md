# Configuración de Permisos en Proxmox para spice-script

Este documento describe cómo configurar los permisos necesarios en Proxmox VE para ejecutar el script `spice.sh` exitosamente.

## Permisos Requeridos

El script utiliza los siguientes endpoints de la API de Proxmox:
- `/api2/json/access/ticket` - Autenticación (no requiere permisos específicos)
- `/api2/json/nodes/$host/qemu/` - Listado de VMs
- `/api2/json/nodes/$host/qemu/$vmid/config` - Configuración de VM
- `/api2/spiceconfig/nodes/$host/qemu/$vmid/spiceproxy` - Configuración SPICE

Para estos endpoints se requieren los siguientes permisos mínimos:
- `VM.Console` - Para acceder a la consola SPICE
- `VM.Audit` - Para listar VMs y ver su configuración

## Configuración Paso a Paso

### 1. Crear un Rol Personalizado

Primero, creamos un rol con los permisos mínimos necesarios:

```bash
# Conectar al servidor Proxmox via SSH como root
pveum role add SpiceConsole -privs "VM.Console,VM.Audit"
```

### 2. Crear un Usuario

Crear el usuario para el script:

```bash
# Crear usuario en el realm PAM (autenticación local)
pveum user add console@pam

# Alternativamente, si usas LDAP/AD, usar el realm correspondiente:
# pveum user add console@ldap
```

### 3. Configurar Contraseña

```bash
# Establecer contraseña para el usuario
pveum passwd console@pam
```

### 4. Asignar Permisos Según el Ámbito Deseado

Elige una de las siguientes opciones según tus necesidades:

#### Opción A: Acceso a Todas las VMs del Datacenter

Esta opción otorga acceso a todas las VMs de todos los nodos:

```bash
# Asignar rol a nivel datacenter
pveum acl modify / -user console@pam -role SpiceConsole
```

**Ventajas:**
- Configuración simple
- Acceso completo a todas las VMs

**Desventajas:**
- Permisos muy amplios
- Menos seguro

#### Opción B: Acceso a Todas las VMs de un Nodo Específico

Esta opción limita el acceso a las VMs de un nodo particular:

```bash
# Reemplazar 'pve' con el nombre real de tu nodo
pveum acl modify /nodes/pve -user console@pam -role SpiceConsole
```

**Ventajas:**
- Permisos limitados por nodo
- Balance entre funcionalidad y seguridad

**Desventajas:**
- Requiere configuración por nodo

#### Opción C: Acceso a VMs Específicas

Esta opción otorga acceso solo a VMs individuales:

```bash
# Para VM con ID 100
pveum acl modify /vms/100 -user console@pam -role SpiceConsole

# Para VM con ID 101
pveum acl modify /vms/101 -user console@pam -role SpiceConsole

# Repetir para cada VM que necesite acceso
```

**Ventajas:**
- Máximo control de seguridad
- Acceso granular por VM

**Desventajas:**
- Configuración más compleja
- Requiere mantenimiento cuando se agregan nuevas VMs

## Verificación de la Configuración

Para verificar que los permisos están correctamente configurados:

```bash
# Verificar permisos del usuario
pveum user permissions console@pam

# Verificar ACLs
pveum acl list
```

## Ejemplo de Configuración Completa

Aquí un ejemplo completo para crear un usuario con acceso a un nodo específico:

```bash
# 1. Crear el rol
pveum role add SpiceConsole -privs "VM.Console,VM.Audit"

# 2. Crear el usuario
pveum user add console@pam

# 3. Establecer contraseña
pveum passwd console@pam

# 4. Asignar permisos al nodo (reemplazar 'pve' con tu nodo)
pveum acl modify /nodes/pve -user console@pam -role SpiceConsole

# 5. Verificar configuración
pveum user permissions console@pam
```

## Configuración del Script

Una vez configurados los permisos, puedes usar el usuario creado en el archivo de configuración del script:

```config
PROXMOX_HOST=tu-servidor-proxmox
PROXMOX_PORT=8006
PROXMOX_USER=console@pam
PROXMOX_PROXY=tu-servidor-proxmox
```

O directamente en la línea de comandos:

```bash
./spice.sh -u console@pam [vmid] [host] [proxy]
```

## Solución de Problemas

### Error de Autenticación
- Verificar que el usuario existe: `pveum user list`
- Verificar que la contraseña es correcta
- Verificar que el realm es correcto (@pam, @ldap, etc.)

### Error de Permisos
- Verificar permisos del usuario: `pveum user permissions console@pam`
- Verificar que el rol tiene los privilegios correctos: `pveum role list`
- Verificar ACLs: `pveum acl list`

### VMs No Visibles
- Verificar que las VMs tienen tarjetas gráficas compatibles (qxl, virtio, virtio-gl)
- Verificar permisos en el ámbito correcto (datacenter/nodo/vm)
