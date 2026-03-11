#!/bin/bash

# Gómez Saavedra, Andrés
# 1ADSIINRE
# gomsaaand12

# Reparación estructural de TFTP, Binarios y Enrutamiento PXE de FOG
# Ejecución estricta como root. Formato de archivo: ESTRICTAMENTE LF (UNIX).

echo "[*] FASE 1: Restauración del servicio TFTP y dependencias..."
dnf install tftp-server wget -y
sed -i 's|/var/lib/tftpboot|/tftpboot|g' /usr/lib/systemd/system/tftp.service
systemctl daemon-reload
setenforce 0
sed -i 's/^SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
systemctl enable --now tftp.socket

echo "[*] FASE 2: Inyección del binario de prearranque (TFTP) y Puente PXE..."
mkdir -p /tftpboot
cd /tftpboot/
rm -f undionly.kpxe default.ipxe

# Descarga del binario iPXE
wget -O undionly.kpxe https://github.com/FOGProject/fogproject/raw/master/packages/tftp/undionly.kpxe

# Creación del archivo de salto (Bridge TFTP -> HTTP) exigido por la arquitectura FOG
cat << 'EOF' > default.ipxe
#!ipxe
cpuid --ext 29 && set arch x86_64 || set arch i386
params
param mac0 ${net0/mac}
param arch ${arch}
param platform ${platform}
param ipxever ${version}
chain http://172.30.0.2/fog/service/ipxe/boot.php##params
EOF

# Permisos restrictivos y de lectura para el demonio TFTP
chmod 644 undionly.kpxe default.ipxe

echo "[*] FASE 3: Reemplazo de los núcleos del sistema y Ramdisks (HTTP)..."
mkdir -p /var/www/html/fog/service/ipxe/
cd /var/www/html/fog/service/ipxe/
rm -f bzImage bzImage32 init.xz init_32.xz

# Descarga de núcleos de ejecución (bzImage)
wget -O bzImage https://fogproject.org/kernels/bzImage
wget -O bzImage32 https://fogproject.org/kernels/bzImage32

# Descarga de los sistemas de archivos virtuales (init.xz). URLs corregidas.
wget -O init.xz https://fogproject.org/inits/init.xz
wget -O init_32.xz https://fogproject.org/inits/init_32.xz

# Cesión de propiedad al demonio Apache para evitar errores HTTP 403 Forbidden
chown apache:apache bzImage* init*

echo "[*] Auditoría final de servicios y archivos:"
ss -unlp | grep 69
ls -lh /tftpboot/undionly.kpxe /tftpboot/default.ipxe
ls -lh /var/www/html/fog/service/ipxe/bzImage /var/www/html/fog/service/ipxe/init.xz