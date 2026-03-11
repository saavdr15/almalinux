#!/bin/bash

# gomsaaand12
# 1ºADSIINRE
# Gómez Saavedra, Andrés

# Restauración y alineación del servicio TFTP para FOG en AlmaLinux 9
# Ejecución estricta como root.

echo "[*] Instalando el paquete tftp-server..."
# dnf instala el binario in.tftpd resolviendo dependencias desde los repositorios.
dnf install tftp-server -y

echo "[*] Alineando la ruta del directorio TFTP con la arquitectura de FOG..."
# El paquete base configura la lectura en /var/lib/tftpboot. 
# FOG requiere rígidamente /tftpboot. Modificamos el archivo de servicio de systemd al vuelo.
sed -i 's|/var/lib/tftpboot|/tftpboot|g' /usr/lib/systemd/system/tftp.service

echo "[*] Recargando el gestor de demonios..."
# systemd mantiene las configuraciones en memoria. Si alteramos un .service con sed, 
# hay que forzar a systemd a releer los archivos del disco o ignorará el cambio.
systemctl daemon-reload

echo "[*] Neutralizando el bloqueo del Control de Acceso Obligatorio (SELinux)..."
# FOG suele fallar al establecer los contextos de seguridad (fcontext) de SELinux en /tftpboot.
# El kernel Linux (MAC) bloqueará silenciosamente la lectura de archivos aunque el puerto esté abierto.
# Pasamos SELinux a modo permisivo en memoria caliente:
setenforce 0
# Y modificamos el archivo de configuración para que el cambio sobreviva a los reinicios:
sed -i 's/^SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config

echo "[*] Habilitando y levantando el socket TFTP..."
# No levantamos tftp.service directamente. Levantamos tftp.socket.
# systemd se quedará a la escucha en el puerto UDP 69 y solo instanciará el demonio 
# in.tftpd cuando reciba tráfico real, ahorrando recursos de memoria.
systemctl enable --now tftp.socket

echo "[*] Proceso finalizado. Auditando puerto 69:"
ss -unlp | grep 69