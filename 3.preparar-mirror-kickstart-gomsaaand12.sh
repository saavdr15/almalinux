#!/bin/bash
# 3.preparar-mirror-kickstart-gomsaaand12.sh

if [ "$EUID" -ne 0 ]; then
  echo "Error: Este script debe ejecutarse como root."
  exit 1
fi

echo "[*] Preparando montaje del medio de instalación..."
mkdir -p /mnt/cd

# Comprobar si el dispositivo existe y si ya está montado
if [ -b "/dev/sr0" ]; then
    if ! mountpoint -q /mnt/cd; then
        mount /dev/sr0 /mnt/cd
        echo "[+] CD-ROM montado correctamente."
    else
        echo "[!] El directorio /mnt/cd ya es un punto de montaje activo. Omitiendo."
    fi
else
    echo "[-] Error: No se detecta el dispositivo de bloques /dev/sr0. Asegúrate de haber insertado la ISO."
    exit 1
fi

echo "[*] Preparando directorio mirror HTTP..."
MIRROR_DIR="/var/www/html/almalinux9-mirror"
mkdir -p "$MIRROR_DIR"

# Evitar copias redundantes de 12GB comprobando si ya existe el kernel
if [ ! -f "$MIRROR_DIR/images/pxeboot/vmlinuz" ]; then
    echo "[*] Copiando estructura del CD al mirror (Esto tomará tiempo)..."
    cp -axv /mnt/cd/* "$MIRROR_DIR/"
else
    echo "[+] El mirror ya parece contener los archivos de instalación. Omitiendo copia masiva."
fi

echo "[*] Generando archivo Kickstart (ks.cfg)..."
cat << 'EOF' > /var/www/html/ks.cfg
lang es_ES.UTF-8
keyboard es
timezone Europe/Madrid
rootpw --iscrypted $6$oDuDJRwaBkFekUOJ$s3K4ojvq8up1.5FcaKAjtGFtHYuzo8D2LL/abpOIRWMl9qmE77Kt9nl2.dGtYc8zTQi5MQ5WDV3Gi8X5oxmz5/
url --url="http://172.30.0.3/almalinux9-mirror"
network --bootproto=dhcp --device=link --activate
authselect --enableshadow --passalgo=sha512
firewall --enabled --ssh
xconfig --startxonboot
firstboot --disable
reboot
bootloader --location=mbr
clearpart --all --initlabel
part swap --size=1024
part / --fstype="xfs" --grow --size=1

%packages
@^workstation-product-environment
%end

%post --log=/root/ks-post-user.log
useradd usuarioalma
echo "usuarioalma:abc123." | chpasswd
%end
EOF

chmod 644 /var/www/html/ks.cfg

echo "[*] Validando sintaxis del archivo Kickstart..."
dnf install pykickstart -y >/dev/null 2>&1
if ksvalidator /var/www/html/ks.cfg; then
    echo "[+] Archivo Kickstart válido."
else
    echo "[-] Error de validación en ks.cfg. Revisa la sintaxis."
    exit 1
fi

echo "[*] Generando script de arranque iPXE principal (boot.ipxe)..."
cat << 'EOF' > /var/www/html/boot.ipxe
#!ipxe
echo Inicializando despliegue desatendido de AlmaLinux 9.7 Workstation...
dhcp
kernel http://172.30.0.3/almalinux9-mirror/images/pxeboot/vmlinuz inst.repo=http://172.30.0.3/almalinux9-mirror inst.ks=http://172.30.0.3/ks.cfg
initrd http://172.30.0.3/almalinux9-mirror/images/pxeboot/initrd.img
boot
EOF

echo "[*] Generando script Chainloader (chain.ipxe)..."
cat << 'EOF' > /var/lib/tftpboot/chain.ipxe
#!ipxe
echo Cargando menu principal desde HTTP...
chain http://172.30.0.3/boot.ipxe || shell
EOF

echo "[*] Ajustando permisos y contextos SELinux..."
chmod 644 /var/lib/tftpboot/chain.ipxe
restorecon -Rv /var/lib/tftpboot/
restorecon -Rv /var/www/html/

echo "[+] Fase 3 completada. Entorno de instalación y menús listos."