#!/bin/bash

# Gómez Saavedra, Andrés
# 1ADSIINRE
# gomsaaand12

# Reparación estructural de TFTP y Binarios de FOG
# Ejecución estricta como root.

echo "[*] FASE 1: Restauración del servicio TFTP y dependencias..."
dnf install tftp-server wget -y
sed -i 's|/var/lib/tftpboot|/tftpboot|g' /usr/lib/systemd/system/tftp.service
systemctl daemon-reload
setenforce 0
sed -i 's/^SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
systemctl enable --now tftp.socket

echo "[*] FASE 2: Inyección del binario de prearranque (TFTP)..."
mkdir -p /tftpboot
cd /tftpboot/
rm -f undionly.kpxe
wget https://github.com/FOGProject/fogproject/raw/master/packages/tftp/undionly.kpxe
chmod 644 undionly.kpxe

echo "[*] FASE 3: Reemplazo de los núcleos del sistema corruptos (HTTP)..."
mkdir -p /var/www/html/fog/service/ipxe/
cd /var/www/html/fog/service/ipxe/
rm -f bzImage bzImage32 init.xz init_32.xz
wget https://fogproject.org/kernels/bzImage
wget https://fogproject.org/kernels/bzImage32
wget https://fogproject.org/images/init.xz
wget https://fogproject.org/images/init_32.xz
chown apache:apache bzImage* init*

echo "[*] Auditoría final de servicios y archivos:"
ss -unlp | grep 69
ls -lh /tftpboot/undionly.kpxe
ls -lh /var/www/html/fog/service/ipxe/bzImage