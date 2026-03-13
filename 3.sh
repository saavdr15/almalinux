#!/bin/bash
# Gómez Saavedra, Andrés | 1ºADSIINRE | gomsaaand12

echo "[*] Instalando el paquete tftp-server..."
dnf install tftp-server -y

echo "[*] Alineando la ruta del directorio TFTP con la arquitectura de FOG..."
# sed reemplaza la cadena antigua por la nueva usando el delimitador '|' para evitar conflictos con las barras '/'.
sed -i 's|/var/lib/tftpboot|/tftpboot|g' /usr/lib/systemd/system/tftp.service

echo "[*] Recargando el gestor de demonios..."
systemctl daemon-reload

echo "[*] Neutralizando el bloqueo del Control de Acceso Obligatorio (SELinux)..."
# setenforce 0 apaga las políticas estrictas de SELinux temporalmente en la sesión actual.
setenforce 0
sed -i 's/^SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config

echo "[*] Habilitando y levantando el socket TFTP..."
systemctl enable --now tftp.socket

echo "[*] Proceso finalizado. Auditando puerto 69:"
ss -unlp | grep 69