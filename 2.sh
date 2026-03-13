#!/bin/bash
# Gómez Saavedra, Andrés | 1ADSIINRE | gomsaaand12

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

wget -O undionly.kpxe https://github.com/FOGProject/fogproject/raw/master/packages/tftp/undionly.kpxe

# Construcción dinámica del archivo iPXE. FOG encadena la carga hacia la IP del servidor web.
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

chmod 644 undionly.kpxe default.ipxe

echo "[*] FASE 3: Reemplazo de los núcleos del sistema y Ramdisks (HTTP)..."
mkdir -p /var/www/html/fog/service/ipxe/
cd /var/www/html/fog/service/ipxe/
rm -f bzImage bzImage32 init.xz init_32.xz

wget -O bzImage https://fogproject.org/kernels/bzImage
wget -O bzImage32 https://fogproject.org/kernels/bzImage32
wget -O init.xz https://fogproject.org/inits/init.xz
wget -O init_32.xz https://fogproject.org/inits/init_32.xz

# SOLUCIÓN CRÍTICA: Asignación recursiva de permisos al demonio Apache sobre toda la ruta de FOG.
# chown -R cambia el propietario (apache) y el grupo (apache) de todo el contenido del directorio.
chown -R apache:apache /var/www/html/fog
# chmod -R 755 garantiza que el propietario puede escribir, y los demás solo leer y ejecutar.
chmod -R 755 /var/www/html/fog