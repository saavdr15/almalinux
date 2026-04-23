#!/bin/bash

# Gómez Saavedra, Andrés
# gomsaaand12
# 1ºADSIINRE, 25/26
# 1. Comprobación de privilegios
if [ "$EUID" -ne 0 ]; then
  echo "Error: Este script debe ejecutarse como root."
  exit 1
fi

echo "[*] Instalando servidor DHCP..."
# 2. Instalación del paquete
dnf install dhcp-server -y

echo "[*] Configurando /etc/dhcp/dhcpd.conf..."
# 3. Inyección de la configuración
cat << 'EOF' > /etc/dhcp/dhcpd.conf
ddns-update-style none;
option user-class code 77 = string;

subnet 172.30.0.0 netmask 255.255.0.0 {
    option routers 172.30.0.3;
    option subnet-mask 255.255.0.0;
    option domain-name "miempresa.local";
    option domain-name-servers 8.8.8.8;
    
    # Servidor TFTP/HTTP donde están los binarios de arranque
    next-server 172.30.0.3; 
    
    range dynamic-bootp 172.30.0.100 172.30.0.200;
    default-lease-time 21600;
    max-lease-time 43200;
    
    # Lógica de Chainloading para iPXE
    if exists user-class and option user-class = "iPXE" {
        filename "chain.ipxe";
    } else {
        filename "undionly.kpxe";
    }
}
EOF

echo "[*] Comprobando sintaxis de la configuración..."
# 4. Validación de sintaxis (Debe ir ANTES de iniciar el servicio)
if dhcpd -t; then
    echo "[+] Sintaxis correcta."
else
    echo "[-] Error de sintaxis en dhcpd.conf. Abortando inicio del servicio."
    exit 1
fi

echo "[*] Permitiendo tráfico DHCP en Firewalld..."
# 5. Regla de firewall (Puerto UDP 67)
firewall-cmd --add-service=dhcp --permanent
firewall-cmd --reload

echo "[*] Habilitando e iniciando el servicio dhcpd..."
# 6. Activación del servicio
systemctl enable --now dhcpd

echo "[+] Fase 1 completada. Servidor DHCP operativo."