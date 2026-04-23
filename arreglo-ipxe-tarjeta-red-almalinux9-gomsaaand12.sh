#!/bin/bash

# Gómez Saavedra, Andrés
# gomsaaand12
# 1ºADSIINRE, 25/26

# Reconstrucción de binarios de arranque PXE/UEFI para FOG Project
# ESTRICTAMENTE PARA EJECUCIÓN COMO ROOT.

# --- 1. CONTROL DE PRIVILEGIOS ---
# Validamos el entorno de ejecución. Si el script no se lanza como root (UID 0), 
# carecerá de permisos para escribir en la raíz del TFTP y debe abortar inmediatamente.
if [[ $EUID -ne 0 ]]; then
   echo "CRÍTICO: Debes ejecutar este script como root o usando sudo."
   exit 1
fi

# --- 2. DECLARACIÓN DE VARIABLES DE ENTORNO ---
# Se centralizan las rutas para facilitar el mantenimiento del código.
# Apuntamos directamente a la rama 'master' del código fuente (raw) de FOG en GitHub.
TFTP_DIR="/tftpboot"
BASE_URL="https://github.com/FOGProject/fogproject/raw/master/packages/tftp"

# Declaramos un array con los binarios estrictamente necesarios.
# - ipxe.pxe / undionly.kpxe -> Para arranques Legacy/BIOS.
# - ipxe.efi / snponly.efi   -> Para arranques UEFI.
BINARIES=(
    "ipxe.pxe"
    "undionly.kpxe"
    "ipxe.efi"
    "snponly.efi"
)

# --- 3. VALIDACIÓN DE E/S DE RED ---
# El fallo raíz de tu infraestructura fue no tener salida a Internet durante la instalación.
# Hacemos un ping de control (1 paquete) a GitHub tirando la salida (stdout/stderr) a /dev/null.
echo "[*] Comprobando resolución DNS y salida a Internet..."
if ! ping -c 1 github.com &> /dev/null; then
    echo "ERROR: El servidor AlmaLinux sigue sin salida a Internet."
    echo "Soluciona tu enrutamiento o los DNS antes de continuar."
    exit 1
fi

# --- 4. BUCLE DE TRANSFERENCIA E INTEGRIDAD ---
echo "[*] Iniciando purga y descarga de binarios en $TFTP_DIR..."

for file in "${BINARIES[@]}"; do
    echo " -> Procesando: $file"
    
    # wget lanza la petición HTTP/HTTPS.
    # -q: Silencia el output verboso para no ensuciar la terminal.
    # -O: Obliga a escribir el flujo de red directamente en el archivo destino.
    wget -q -O "${TFTP_DIR}/${file}" "${BASE_URL}/${file}"
    
    # Comprobación del código de salida de wget (0 = Éxito).
    if [ $? -eq 0 ]; then
        # Establecemos máscara octal 755:
        # Propietario (root): Lectura, Escritura, Ejecución.
        # Grupo y Otros (Demonio TFTP): Lectura y Ejecución. Vital para que in.tftpd pueda servirlo.
        chmod 755 "${TFTP_DIR}/${file}"
        echo "    [OK] Descargado y permisos aplicados."
    else
        echo "    [FAIL] Falló la descarga. Revisa el enlace o el proxy."
    fi
done

# --- 5. AUDITORÍA FINAL ---
# Imprimimos un listado filtrado con el tamaño de los archivos para confirmar 
# que no se han descargado binarios corruptos o vacíos de 0 bytes.
echo -e "\n[*] Operación finalizada. Auditoría de $TFTP_DIR:"
ls -lh $TFTP_DIR | grep -E "(ipxe|undionly|snponly)"