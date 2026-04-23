#!/bin/bash
# Gómez Saavedra, Andrés
# gomsaaand12
# 1ºADSIINRE, 25/26and12.sh

if [ "$EUID" -ne 0 ]; then
  echo "Error: Ejecuta como root."
  exit 1
fi

echo "[*] Reescribiendo /etc/dhcp/dhcpd.conf con lógica de capacidades..."
cat << 'EOF' > /etc/dhcp/dhcpd.conf
ddns-update-style none;

# Definimos el espacio de opciones nativo de iPXE para extraer sus 'Features'
option space ipxe;
option ipxe-encap-opts code 175 = encapsulate ipxe;
option ipxe.http code 19 = unsigned integer 8;

subnet 172.30.0.0 netmask 255.255.0.0 {
    option routers 172.30.0.3;
    option subnet-mask 255.255.0.0;
    option domain-name "miempresa.local";
    option domain-name-servers 8.8.8.8;
    
    next-server 172.30.0.3; 
    
    range dynamic-bootp 172.30.0.100 172.30.0.200;
    default-lease-time 21600;
    max-lease-time 43200;
    
    # Lógica de Chainloading basada en CAPACIDADES, no en nombres.
    if exists ipxe.http {
        # Si el cliente soporta HTTP, le servimos el script de arranque directamente por Apache.
        # Ya no usamos TFTP ni chain.ipxe para esta fase.
        filename "http://172.30.0.3/boot.ipxe";
    } else {
        # Si el cliente es una BIOS normal o la ROM deficiente de VirtualBox,
        # le pasamos el binario completo de iPXE por TFTP.
        filename "undionly.kpxe";
    }
}
EOF

echo "[*] Comprobando sintaxis..."
if dhcpd -t; then
    echo "[+] Sintaxis correcta. Reiniciando dhcpd..."
    systemctl restart dhcpd
else
    echo "[-] Error de sintaxis al generar el nuevo dhcpd.conf."
    exit 1
fi

echo "[+] DHCP parcheado."