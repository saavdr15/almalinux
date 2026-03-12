#!/bin/bash
# Reparación del túnel de almacenamiento NFS para FOG en AlmaLinux 9
# Ejecución estricta como root. Formato LF.

echo "[*] Instalando dependencias de almacenamiento en red..."
# dnf instala el demonio nfs-server y utilidades como showmount.
dnf install nfs-utils -y

echo "[*] Reconstruyendo estructura de almacenamiento y permisos..."
# Aseguramos que existan las carpetas donde FOG guarda las imágenes.
mkdir -p /images/dev
# Aplicamos permisos de escritura globales para que Partclone no sufra un "Access Denied" al volcar bloques.
chmod -R 777 /images

echo "[*] Escribiendo tabla de exportación estricta de FOG..."
# FOG requiere exportar la raíz (/images) para despliegue y la carpeta de desarrollo (/images/dev) para captura.
# El parámetro "no_root_squash" es vital: permite que el cliente remoto actúe como root sobre esos archivos.
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

echo "[*] Auditoría del servidor NFS (Deberías ver tus rutas /images aquí):"
showmount -e 127.0.0.1