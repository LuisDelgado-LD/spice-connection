# spice-conn
El script fue diseñado para evitar tener que acceder por la web de proxmox solo para iniciar una consola spice en una de las vms.

## Instalación

Basta con clonar este repositorio y conceder permisos de ejecución al script `spice.sh`

``` bash
git clone https://github.com/LuisDelgado-LD/spice-connection
chmod +x spice-connection/spice.sh
./spice-connection/spice.sh [-u <usuario>] vmid [host [proxy]] 
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

## Funcionamiento

existen dos formas de ejecutar el script

### Archivo de configuración (recomendado)

La primera forma consiste en crear un archivo en la ruta `~/.config/pve-spice/config` indicando los valores de la variables. 

Ejemplo

``` config 
PROXMOX_HOST=10.10.10.125
PROXMOX_PORT=8006
PROXMOX_USER=console@pve
PROXMOX_PROXY=10.10.10.100
```
### usando argumentos

La segunda forma consiste en indicar por consola los distintos argumentos necesarios para la ejecución del script

Por ejemplo, para conectarnos por consola SPICE a la vm **100** del servidor proxmox con nombre **proxmox.local** usando el usuario **console@pve**, en este caso ejecutaremos

`spice.sh 100 proxmox.local -u console@pve`

> [!important] 
> El orden de los argumentos **si** importa cuando utilizamos el argumento -u <usuario>
> este debe ir o **al inicio o al final** y no debe ser utilizado entre los argumentos posicionales (vmid host proxy)

### Jerarquia

Los argumentos utilizados por consola **siempre** tendrán preferencia por sobre los indicados en el archivo de configuración

## Inspiración

Este script fue inspirado por [este script](https://git.proxmox.com/?p=pve-manager.git;a=blob_plain;f=spice-example-sh;hb=HEAD) encontrado en la [documentación de proxmox](https://pve.proxmox.com/wiki/SPICE)

## Proximos pasos (AKA Roadmap)

- [ ] Buscar los permisos necesarios para crear un usuario en proxmox
- [ ] Mostrar un listado de las vms del nodo
- [ ] Ejecutar consola por nombre de vm o por id
- [ ] Añadir soporte a consola NoVNC
- [ ] Función interactiva para creación del archivo de configuración 
- [ ] Crear script utilizando python (compatibilidad con windows)