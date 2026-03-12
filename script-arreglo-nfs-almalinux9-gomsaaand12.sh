#!/bin/bash
# Gómez Saavedra, Andrés
# 1ADSIINRE
# gomsaaand12

# Reparación del túnel de almacenamiento NFS y validación para FOG en AlmaLinux 9
# Ejecución estricta como root. Formato LF innegociable.

echo "[*] Instalando dependencias de almacenamiento en red..."
# dnf instala el demonio nfs-server y utilidades como showmount.
dnf install nfs-utils -y

echo "[*] Reconstruyendo estructura de almacenamiento y archivos de validación..."
# Aseguramos que existan las carpetas donde FOG guarda las imágenes.
mkdir -p /images/dev

# Mecanismo de seguridad (Sanity Check) de FOG
# FOG exige estos archivos vacíos para confirmar que el volumen remoto se montó correctamente.
touch /images/.mntcheck
touch /images/dev/.mntcheck

# Aplicamos permisos globales para que Partclone no sufra un "Access Denied" al volcar bloques.
chmod -R 777 /images

echo "[*] Escribiendo tabla de exportación estricta de FOG..."
# FOG requiere exportar la raíz (/images) para despliegue y la carpeta temporal (/images/dev) para captura.
# El parámetro "no_root_squash" es vital: permite que el cliente remoto actúe como root sobre la red.
cat << 'EOF' > /etc/exports
/images *(ro,sync,no_wdelay,insecure_locks,no_root_squash,insecure,fsid=0)
/images/dev *(rw,async,no_wdelay,no_root_squash,insecure,fsid=1)
EOF

echo "[*] Levantando demonios y aplicando configuración al kernel..."
# rpcbind mapea los puertos dinámicos para NFS. Es obligatorio.
systemctl enable --now rpcbind
systemctl enable --now nfs-server
# exportfs -ra fuerza al demonio NFS a releer el archivo /etc/exports e inyectarlo en memoria.
exportfs -ra

echo "[*] Auditoría final del servidor NFS y ficheros de control:"
showmount -e 127.0.0.1
ls -la /images/.mntcheck /images/dev/.mntcheck