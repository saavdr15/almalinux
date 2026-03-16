#!/bin/bash

# Gómez Saavedra, Andrés
# 1ADSIINRE
# gomsaaand12

# 1. Actualizar dnf
dnf update -y

# 2. Instalar el grupo de herramientas de desarrollo y cabeceras específicas
dnf install -y gcc make perl kernel-devel-$(uname -r) kernel-headers-$(uname -r) elfutils-libelf-devel

# 3. Reinicio recomendado
echo "Si se ha actualizado el kernel, reinicia antes de montar la ISO de VBox."