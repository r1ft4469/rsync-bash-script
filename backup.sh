#!/bin/bash
EXCLUDE=()
# DEFINE EXCLUDED FILES AND FLODERS HERE
# ======================================
EXCLUDE+=("/dev/*")
EXCLUDE+=("/prc/*")
EXCLUDE+=("/sys/*")
EXCLUDE+=("/tmp/*")
EXCLUDE+=("/run/*")
EXCLUDE+=("/mnt/*")
EXCLUDE+=("/media/*")
EXCLUDE+=("/lost+found")
EXCLUDE+=("/home/r1ft/.wine")
EXCLUDE+=("/home/r1ft/Drive")
EXCLUDE+=("/home/r1ft/vmware")
EXCLUDE+=("/home/r1ft/r1ft-vault")
EXCLUDE+=("/home/iitc/Drive")
# ======================================
# VARS
# ============================
BACKUPLOCATION=root@20.20.20.200:/mnt/Vault/Backup
BACKUPNAME=$(uname -n)
# ===========================
# SCRIPT
# ============================

#CHECK UID FOR ROOT
if [ "$EUID" -ne 0 ]; then 
	echo "Please run as root"
	exit
fi

#CHECK DEPENDANCIES
PACKAGEERROR=0
echo "Checking Dependancies"
echo "====================="
if [ $(which rsync 2>/dev/null) ]; then
	echo $(rsync --version | head -1)
else
	echo "rsync Not Found"
	PACKAGEERROR=1
fi
if [ $(which tar 2>/dev/null) ]; then
	echo $(tar --version | head -1)
else
	echo "tar Not Found"
	PACKAGEERROR=1
fi
if [ $(which gpg 2>/dev/null) ]; then
	echo $(gpg --version | head -1)
else
	echo "gpg Not Found"
	PACKAGEERROR=1
fi
if [ $(which pv 2>/dev/null) ]; then
	echo $(pv --version | head -1)
else
	echo "pv Not Found"
	PACKAGEERROR=1
fi
if [ $(which ssh 2>/dev/null) ]; then
	echo $(ssh -V | grep SSH)
else
	echo "ssh Not Found"
	PACKAGEERROR=1
fi
if [ $PACKAGEERROR = 1 ]; then
	echo "Dependancies Not Met"
	exit
else
	echo "Dependancies Installed"
fi
echo -e "\n"

#ASK FOR GPG PASSPHRASE
while true; do
	read -s -p "Backup Password: " PASSWORD
	echo -e '\n'
	read -s -p "Repeat Backup Password: " PASSWORD_CHECK
	if [ $PASSWORD = $PASSWORD_CHECK ]; then
		break
	else
		echo -e "\nPassword Did Not Match"
	fi		
done
GPGPASSWORD=$PASSWORD
PASSWORD=""
PASSWORD_CHECK=""

#MAKE MOUNT FOLDER IN /tmp
if [ ! -d "/tmp/backupmount" ]; then
	mkdir /tmp/backupmount
fi

#MOUNT SFTP BACKUP LOCATION
sudo sshfs $BACKUPLOCATION /tmp/backupmount
if [ ! -d "/tmp/backupmount/arch-laptop" ]; then
	mkdir /tmp/backupmount/$BACKUPNAME
fi

#SET CURRENT WORKING DIR
currentdir=$(pwd)

#MOVE TO MOUNT LOCATION
cd /tmp/backupmount

#BUILD EXLUDE FILE
if [ -f /tmp/exclude_files.txt ]; then
	rm /tmp/exclude_files.txt
fi
for i in ${!EXCLUDE[*]}
do
	echo "${EXCLUDE[$i]}" >> /tmp/exclude_files.txt
done

#COUNT FILES TO BACKUP
FCNT=$(rsync -r --dry-run --stats --human-readable --exclude-from='/tmp/exclude_files.txt' / $BACKUPNAME | grep 'Number of files:' | sed 's/(.*//' | sed 's/ //g' | sed 's/,//g' | sed 's/.*://g')

#BACKUP TO FOLDER ON SFTP
rsync -aAXviO --stats --human-readable --exclude=$EXCLUDESTRING / $BACKUPNAME | pv -lep -s $FCNT >/dev/null 

#TAR FILES ON SFTP
tar -vz -cf $BACKUPNAME.tar.gz $BACKUPNAME

#REMOVE BACKUP FILES
rm -rf $BACKUPNAME/

#ENCRYPT TAR
echo $GPGPASSWORD | gpg --batch --passphrase-fd 0 -c -o $BACKUPNAME.gpg $BACKUPNAME.tar.gz
GPGPASSWORD=""

#REMOVE BACKUP TAR
rm $BACKUPNAME.tar.gz

#MAKE RECOVERY SCRIPT
echo -e '#!/bin/bash/\n' >> $BACKUPNAME-recover.sh
echo -e "\n" >> $BACKUPNAME-recover.sh
RESTORESTRING='RESTORENAME='$BACKUPNAME
RESTORELOCATIONSTRING='RESTORELOCATION='$BACKUPLOCATION
echo $RESTORESTRING >> $BACKUPNAME-recover.sh
echo $RESTORELOCATIONSTRING >> $BACKUPNAME-recover.sh
echo -e '\n' >> $BACKUPNAME-recover.sh
echo -e "read -s -p \"Backup Password: \" GPGPASSWORD
if [ \"\$EUID\" -ne 0 ]; then 
	\"Please run as root\"
	exit
fi
PACKAGEERROR=0
echo \"Checking Dependancies\"
echo \"=====================\"
if [ \$(which rsync 2>/dev/null) ]; then
	echo \$(rsync --version | head -1)
else
	echo \"rsync not found\"
	PACKAGEERROR=1
fi
if [ \$(which tar 2>/dev/null) ]; then
	echo \$(tar --version | head -1)
else
	echo \"tar not found\"
	PACKAGEERROR=1
fi
if [ \$(which gpg 2>/dev/null) ]; then
	echo \$(gpg --version | head -1)
else
	echo \"gpg not found\"
	PACKAGEERROR=1
fi
if [ \$(which pv 2>/dev/null) ]; then
	echo \$(pv --version | head -1)
else
	echo \"pv not found\"
	PACKAGEERROR=1
fi
if [ \$(which ssh 2>/dev/null) ]; then
	echo \$(ssh -V)
else
	echo \"ssh not found\"
	PACKAGEERROR=1
fi
if [ \$PACKAGEERROR = 1 ]; then
	echo \"Dependances not met\"
	exit
fi
if [ ! -d \"/tmp/restore\" ]; then
	mkdir /tmp/restore
fi
sshfs \$RESTORELOCATION /tmp/restore
currentdir=\$(pwd)
cd /tmp/restore
echo \$GPGPASSWORD | gpg --batch --passphrase-fd 0 -output \$RESTORENAME.tar.gz -d \$RESTORENAME.gpg
GPGPASSWORD=\"\"
rm \$RESTORENAME.gpg
tar -xvf \$RESTORENAME.tar.gz
rm \$RESOTRENAME.tar.gz
FNCT=\$(rsync -r --dry-run --ignore-existing --stats --human-readable --exclude={\"ect/fstab\"} \$RESTORENAME/ / | grep 'Number of files:' | sed 's/(.*//' | sed 's/,//g' | sed 's/.*//g')
rsync -aAXv --info=progress2 --exclude={\"etc/fstab\"} \$RESTORENAME/ / | pv -lep -s \$FCNT >/dev/null
rm -rf \$RESTORENAME/
cp \$currentdir
sleep 5
fusermount -u /tmp/restore" >> $BACKUPNAME-recover.sh

#RETURN TO WORKING DIR
cd $currentdir

#SLEEP AND UNMOUNT
sleep 5
fusermount -u /tmp/backupmount
rm -rf /tmp/backupmount
rm /tmp/exclude_files.txt

#EXIT
ECHO "Backup Finished"
exit 0
