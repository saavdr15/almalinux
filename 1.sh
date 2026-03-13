#!/bin/bash
# Gómez Saavedra, Andrés | 1ADSIINRE | gomsaaand12

echo "[*] FASE 1: Reconstrucción del Túnel NFS (Captura de bloques)..."
dnf install nfs-utils -y
mkdir -p /images/dev
touch /images/.mntcheck
touch /images/dev/.mntcheck
chmod -R 777 /images # Fuerza bruta: Otorga permisos de lectura, escritura y ejecución a todos los usuarios.

# Heredoc (EOF): Sobrescribe el archivo de exportaciones NFS con la configuración innegociable de FOG.
cat << 'EOF' > /etc/exports
/images *(ro,sync,no_wdelay,insecure_locks,no_root_squash,insecure,fsid=0)
/images/dev *(rw,async,no_wdelay,no_root_squash,insecure,fsid=1)
EOF

systemctl enable --now rpcbind
systemctl enable --now nfs-server
exportfs -ra # Obliga al kernel a releer la tabla de exportaciones NFS sin reiniciar el servicio.

echo "[*] FASE 2: Reconstrucción del Túnel FTP..."
dnf install vsftpd mariadb -y

# grep/cut/tr: Busca la línea de la contraseña, corta por el igual (=) y elimina comillas para aislar la clave.
FOG_PASS=$(grep 'password=' /opt/fog/.fogsettings | cut -d '=' -f 2 | tr -d \' | tr -d \")

if [ -z "$FOG_PASS" ]; then
    FOG_PASS="fogpassword123"
fi

# sed: Busca líneas comentadas específicas en vsftpd.conf y las descomenta reemplazándolas al vuelo.
sed -i 's/^#write_enable=YES/write_enable=YES/g' /etc/vsftpd/vsftpd.conf
sed -i 's/^#local_enable=YES/local_enable=YES/g' /etc/vsftpd/vsftpd.conf

useradd fogproject 2>/dev/null
echo "fogproject:$FOG_PASS" | chpasswd

mysql fog -e "UPDATE nfsGroupMembers SET ngmPass='$FOG_PASS' WHERE ngmMemberName='DefaultMember';"

systemctl enable --now vsftpd
systemctl restart vsftpd

echo "[*] FASE 2.5: Apertura de Firewall y Puertos Pasivos FTP..."
echo "pasv_enable=YES" >> /etc/vsftpd/vsftpd.conf
echo "pasv_min_port=30000" >> /etc/vsftpd/vsftpd.conf
echo "pasv_max_port=30100" >> /etc/vsftpd/vsftpd.conf
echo "seccomp_sandbox=NO" >> /etc/vsftpd/vsftpd.conf

systemctl restart vsftpd

if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-service=ftp
    firewall-cmd --permanent --add-service=nfs
    firewall-cmd --permanent --add-service=rpc-bind
    firewall-cmd --permanent --add-service=mountd
    firewall-cmd --permanent --add-port=30000-30100/tcp
    # SOLUCIÓN CRÍTICA: Apertura del tráfico web para que iPXE no reciba un HTTP 403 o Connection Refused.
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
fi

echo "[*] FASE 3: Destrucción de tareas zombi previas..."
rm -rf /images/dev/* 2>/dev/null
touch /images/dev/.mntcheck
chmod -R 777 /images