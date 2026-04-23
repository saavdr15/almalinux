#!/bin/bash
# 1.instalar-dhcp-definitivo.sh

# 1. Bloqueo de ejecución sin privilegios
if [ "$EUID" -ne 0 ]; then
  echo "[-] Error crítico: La manipulación de demonios de red requiere privilegios de root."
  exit 1
fi

echo "[*] Fase 1/5: Instalando binarios del servidor DHCP..."
dnf install dhcp-server -y

echo "[*] Fase 2/5: Inyectando configuración unificada en /etc/dhcp/dhcpd.conf..."
# Utilizamos un Here-Doc para sobrescribir el archivo con la lógica de capacidades (RFC 2132 + iPXE)
cat << 'EOF' > /etc/dhcp/dhcpd.conf
ddns-update-style none;

# Declaración del espacio de opciones encapsuladas para diseccionar las peticiones de iPXE
option space ipxe;
option ipxe-encap-opts code 175 = encapsulate ipxe;
option ipxe.http code 19 = unsigned integer 8;

subnet 172.30.0.0 netmask 255.255.0.0 {
    option routers 172.30.0.3;
    option subnet-mask 255.255.0.0;
    option domain-name "miempresa.local";
    option domain-name-servers 8.8.8.8;
    
    # Puntero a la IP del servidor que aloja los binarios de arranque
    next-server 172.30.0.3; 
    
    range dynamic-bootp 172.30.0.100 172.30.0.200;
    default-lease-time 21600;
    max-lease-time 43200;
    
    # Enrutamiento de peticiones PXE basado en la bandera de soporte HTTP (Feature 19)
    if exists ipxe.http {
        # El cliente tiene pila TCP/IP completa y soporta HTTP. Disparamos directo contra Apache.
        filename "http://172.30.0.3/boot.ipxe";
    } else {
        # El cliente es tonto (BIOS legacy o ROM VBox). Le inyectamos el binario iPXE por TFTP.
        filename "undionly.kpxe";
    }
}
EOF

echo "[*] Fase 3/5: Realizando análisis sintáctico del archivo de configuración..."
# Validación estricta antes de tocar el demonio. Si el código de salida no es 0, abortamos.
if dhcpd -t; then
    echo "[+] Árbol sintáctico de dhcpd.conf validado."
else
    echo "[-] Error fatal: dhcpd.conf contiene errores de sintaxis. Revisa el código."
    exit 1
fi

echo "[*] Fase 4/5: Perforando Firewalld para tráfico UDP 67..."
# Aunque desactives el firewall más adelante, la infraestructura base debe estar diseñada para soportarlo.
firewall-cmd --add-service=dhcp --permanent
firewall-cmd --reload

echo "[*] Fase 5/5: Enganchando servicio a systemd e inicializando..."
# enable --now crea el symlink en multi-user.target e inicia el proceso hijo.
systemctl enable --now dhcpd

echo "[+] Infraestructura DHCP operativa y parcheada para VirtualBox."