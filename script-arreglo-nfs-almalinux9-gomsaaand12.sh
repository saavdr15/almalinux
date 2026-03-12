#!/bin/bash
# Gómez Saavedra, Andrés
# 1ADSIINRE
# gomsaaand12

# Reparación integral del Subsistema de Almacenamiento (NFS) y Transferencia (FTP) para FOG
# Ejecución estricta como root. Formato LF innegociable.

echo "[*] FASE 1: Reconstrucción del Túnel NFS (Captura de bloques)..."
dnf install nfs-utils -y
mkdir -p /images/dev
touch /images/.mntcheck
touch /images/dev/.mntcheck
chmod -R 777 /images

cat << 'EOF' > /etc/exports
/images *(ro,sync,no_wdelay,insecure_locks,no_root_squash,insecure,fsid=0)
/images/dev *(rw,async,no_wdelay,no_root_squash,insecure,fsid=1)
EOF

systemctl enable --now rpcbind
systemctl enable --now nfs-server
exportfs -ra

echo "[*] FASE 2: Reconstrucción del Túnel FTP (Renombrado y validación final)..."
dnf install vsftpd mariadb -y

# Extracción de la clave maestra de FOG del archivo de instalación
FOG_PASS=$(grep 'password=' /opt/fog/.fogsettings | cut -d '=' -f 2 | tr -d \' | tr -d \")

# Autocorrección si el instalador dejó la contraseña en blanco
if [ -z "$FOG_PASS" ]; then
    FOG_PASS="fogpassword123"
fi

# Configuración estricta de escritura local en vsftpd
sed -i 's/^#write_enable=YES/write_enable=YES/g' /etc/vsftpd/vsftpd.conf
sed -i 's/^#local_enable=YES/local_enable=YES/g' /etc/vsftpd/vsftpd.conf

# Sincronización del usuario a nivel de Sistema Operativo
useradd fogproject 2>/dev/null
echo "fogproject:$FOG_PASS" | chpasswd

# Sincronización del usuario a nivel de Base de Datos MariaDB
mysql fog -e "UPDATE nfsGroupMembers SET ngmPass='$FOG_PASS' WHERE ngmMemberName='DefaultMember';"

systemctl enable --now vsftpd
systemctl restart vsftpd

echo "[*] FASE 3: Destrucción de tareas zombi previas..."
# Purgamos imágenes temporales fallidas para empezar desde cero
rm -rf /images/dev/* 2>/dev/null
# Restauramos el archivo .mntcheck que el rm acaba de destruir y sellamos permisos
touch /images/dev/.mntcheck
chmod -R 777 /images

echo "[*] Auditoría de la Infraestructura de Almacenamiento:"
showmount -e 127.0.0.1
echo "-> Contraseña FTP inyectada en AlmaLinux y MariaDB: $FOG_PASS"