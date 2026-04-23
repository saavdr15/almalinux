#!/bin/bash
# Gómez Saavedra, Andrés
# gomsaaand12
# 1ºADSIINRE, 25/26

# 1. Comprobación de privilegios
if [ "$EUID" -ne 0 ]; then
  echo "Error: Este script debe ejecutarse como root."
  exit 1
fi

echo "[!] ADVERTENCIA: Desactivando Firewalld..."
# 2. Desactivación del Firewall (Práctica no recomendada)
systemctl stop firewalld
systemctl disable firewalld

echo "[*] Instalando Apache (HTTPD), servidor TFTP y binarios iPXE..."
# 3. Instalación de paquetes
dnf install httpd tftp-server ipxe-bootimgs -y

echo "[*] Habilitando e iniciando servicios HTTP y TFTP..."
# 4. Activación de servicios
systemctl enable --now httpd
systemctl enable --now tftp.socket

echo "[*] Copiando binario de arranque undionly.kpxe al directorio TFTP..."
# 5. Despliegue del binario PXE
if [ -f "/usr/share/ipxe/undionly.kpxe" ]; then
    cp /usr/share/ipxe/undionly.kpxe /var/lib/tftpboot/
else
    echo "[-] Error: No se encuentra /usr/share/ipxe/undionly.kpxe. Verifica el paquete ipxe-bootimgs."
    exit 1
fi

echo "[*] Restaurando contextos de SELinux en /var/lib/tftpboot/..."
# 6. Corrección de contextos SELinux
restorecon -Rv /var/lib/tftpboot/

echo "[+] Fase 2 completada. HTTP y TFTP operativos."