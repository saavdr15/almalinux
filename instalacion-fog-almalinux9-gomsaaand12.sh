#!/bin/bash

# Gómez Saavedra, Andrés
# 1ADSIINRE
# gomsaaand12

# Ejecución como root.

echo "Se instalará todo en el directorio actual. Tienes 5 segundos para cancelar el script"

echo "[*] Instalación desde el repositorio oficial de FOG..."
wget https://api.github.com/repos/FOGProject/fogproject/tarball/1.5.10.1763

echo "[*] Descompresión del archivo instalado..."
tar -xzvf 1.5.10.1763

echo "[*] Entrada al directorio y ejecución del script de instalación..."
cd FOGProject-fogproject-2506723/
cd bin/
bash installfog.sh

echo "INSTALACIÓN TERMINADA"