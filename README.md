# spice-conn
El script fue diseñado para evitar tener que acceder por la web de proxmox solo para iniciar una consola spice en una de las vms.

## Instalación

Basta con clonar este repositorio y conceder permisos de ejecución al script `spice.sh`

``` bash
git clone https://github.com/LuisDelgado-LD/spice-connection
chmod +x spice-connection/spice.sh
./spice-connection/spice.sh [-u <usuario>] [vmid] [host [proxy]] 
```

Además se debe instalar la herramienta remote-viewer, dependiendo del SO

### Debian y derivados

`sudo apt install virt-viewer`

### RHEL y derivados

`sudo dnf install virt-viewer`

### Arch y derivados

`sudo pacman -S virt-viewer`

### OpenSUSE

`sudo zypper install virt-viewer`

### Configuración de Permisos en Proxmox

Para que el script funcione correctamente, es necesario configurar los permisos adecuados en Proxmox VE. Consulta la guía detallada en [PERMISOS_PROXMOX.md](PERMISOS_PROXMOX.md) para:

- Crear un usuario dedicado para el script
- Configurar los permisos mínimos necesarios
- Elegir el ámbito de acceso apropiado (datacenter, nodo o VMs específicas)


## Funcionamiento

Existen diferentes formas de ejecutar el script:

### Modo interactivo (sin especificar VMID)

Si ejecutas el script sin especificar un ID de VM, se mostrará automáticamente una lista de todas las VMs compatibles con SPICE del nodo:

```bash
./spice.sh [-u <usuario>] [host [proxy]]
```

El script te permitirá:
- Ver todas las VMs que tienen SPICE habilitado (con tarjetas gráficas qxl, virtio o virtio-gl)
- Seleccionar interactivamente qué VM usar introduciendo su ID
- Cancelar la operación presionando Enter sin introducir ningún ID

### Modo directo (especificando VMID)

También puedes conectarte directamente a una VM específica proporcionando su ID:

```bash
./spice.sh [-u <usuario>] vmid [host [proxy]]
```

Por ejemplo, para conectarnos por consola SPICE a la vm **100** del servidor proxmox con nombre **proxmox.local** usando el usuario **console@pve**:

```bash
./spice.sh -u console@pve 100 proxmox.local
```

### Archivo de configuración (recomendado)

La primera forma consiste en crear un archivo en la ruta `~/.config/pve-spice/config` indicando los valores de la variables. 

Ejemplo

``` config 
PROXMOX_HOST=10.10.10.125
PROXMOX_PORT=8006
PROXMOX_USER=console@pve
PROXMOX_PROXY=10.10.10.100
```

### Usando argumentos

También puedes especificar todos los parámetros directamente desde la línea de comandos:

Por ejemplo, para conectarnos por consola SPICE a la vm **100** del servidor proxmox con nombre **proxmox.local** usando el usuario **console@pve**:

```bash
./spice.sh -u console@pve 100 proxmox.local
```

O para ver la lista de VMs disponibles en un servidor específico:

```bash
./spice.sh -u console@pve proxmox.local
```

> [!important] 
> El orden de los argumentos **si** importa cuando utilizamos el argumento -u <usuario>
> este debe ir o **al inicio o al final** y no debe ser utilizado entre los argumentos posicionales (vmid host proxy)

### Jerarquia

Los argumentos utilizados por consola **siempre** tendrán preferencia por sobre los indicados en el archivo de configuración

## Inspiración

Este script fue inspirado por [este script](https://git.proxmox.com/?p=pve-manager.git;a=blob_plain;f=spice-example-sh;hb=HEAD) encontrado en la [documentación de proxmox](https://pve.proxmox.com/wiki/SPICE)

## Proximos pasos (AKA Roadmap)

- [X] Buscar los permisos necesarios para crear un usuario en proxmox
- [X] Mostrar un listado de las vms del nodo
- [X] Ejecutar consola por nombre de vm o por id
- [ ] Añadir soporte a consola NoVNC
- [ ] Función interactiva para creación del archivo de configuración 
- [ ] Crear script utilizando python (compatibilidad con windows)

## Nota de desarrollo

Parte del código de este proyecto ha sido desarrollado con apoyo de GitHub Copilot.