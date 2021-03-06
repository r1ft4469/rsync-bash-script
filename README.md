# rsync-bash-script
Rsync Bash Script for backing up arch linux with a gpg encrypted container

```
#!/bin/bash
EXCLUDE=()
# DEFINE EXCLUDED FILES AND FLODERS HERE
# ======================================
EXCLUDE+=("/dev/*")
EXCLUDE+=("/proc/*")
EXCLUDE+=("/sys/*")
EXCLUDE+=("/tmp/*")
EXCLUDE+=("/run/*")
EXCLUDE+=("/mnt/*")
EXCLUDE+=("/media/*")
EXCLUDE+=("/lost+found")
# ======================================
# VARS
# ============================
BACKUPLOCATION=user@20.20.20.20:/mnt/Vault/Backup
BACKUPNAME=$(uname -n)
# ===========================
# SCRIPT
# ============================

#COLOR CODES
NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'

#CHECK UID FOR ROOT
if [ "$EUID" -ne 0 ]; then 
	echo -e ${RED}"Please run as root"
	exit
fi

#PRINT HEADER
echo -e ${NC}"rsync System Backup Script by "${BLUE}"r1ft"${NC}
echo "====================="

#CHECK DEPENDANCIES
PACKAGEERROR=0
echo "Checking Dependancies"
echo "====================="
if [ $(which rsync 2>/dev/null) ]; then
	echo -e ${GREEN}$(rsync --version | head -1)
else
	echo -e ${RED}"rsync Not Found"
	PACKAGEERROR=1
fi
if [ $(which tar 2>/dev/null) ]; then
	echo -e ${GREEN}$(tar --version | head -1)
else
	echo -e ${RED}"tar Not Found"
	PACKAGEERROR=1
fi
if [ $(which gpg 2>/dev/null) ]; then
	echo -e ${GREEN}$(gpg --version | head -1)
else
	echo -e ${RED}"gpg Not Found"
	PACKAGEERROR=1
fi
if [ $(which pv 2>/dev/null) ]; then
	echo -e ${GREEN}$(pv --version | head -1)
else
	echo -e ${RED}"pv Not Found"
	PACKAGEERROR=1
fi
if [ $(which ssh 2>/dev/null) ]; then
	echo -en ${GREEN}
	ssh -V
else
	echo -e ${RED}"ssh Not Found"
	PACKAGEERROR=1
fi
echo -e ${NC}"====================="
if [ $PACKAGEERROR = 1 ]; then
	echo -e ${RED}"Dependancies Not Met"
	exit
else
	echo -e ${GREEN}"All Dependancies Installed"
fi
echo -e ${NC}"====================="

#ASK FOR GPG PASSPHRASE
while true; do
	read -s -p "Backup Password: " PASSWORD
	echo -e ''
	read -s -p "Repeat Backup Password: " PASSWORD_CHECK
	echo -e ''
	if [ $PASSWORD = $PASSWORD_CHECK ]; then
		break
	else
		echo -e ${RED}"Password Did Not Match"
		echo -en ${NC}
	fi		
done
echo "Starting Backup ..."
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
if [ -f /tmp/exclude.txt ]; then
	rm /tmp/exclude.txt
fi
for i in ${!EXCLUDE[*]}
do
	echo "${EXCLUDE[$i]}" >> /tmp/exclude.txt
done

#COUNT FILES TO BACKUP
echo -en ${GREEN}
FCNT=$(rsync -r --dry-run --stats --human-readable --exclude-from='/tmp/exclude.txt' -e ssh / $BACKUPLOCATION/$BACKUPNAME | grep 'Number of files:' | sed 's/(.*//' | sed 's/ //g' | sed 's/,//g' | sed 's/.*://g')

#BACKUP TO FOLDER ON SFTP
rsync -aAXviO --stats --human-readable --exclude-from='/tmp/exclude.txt' -e ssh / $BACKUPLOCATION/$BACKUPNAME | pv -lepb -s $FCNT >/dev/null 

#TAR FILES ON SFTP
echo -e ${NC}"Making tar of Backup ..."${GREEN}
tar -vz -cf $BACKUPNAME.tar.gz $BACKUPNAME | pv -lepb -s $FCNT >/devnull

#REMOVE BACKUP FILES
rm -rf $BACKUPNAME/

#ENCRYPT TAR
echo -e ${NC}"Encrypting tar ..."${GREEN}
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
#COLOR CODES
NC='\\033[0m'
RED='\\033[0;31m'
GREEN='\\033[0;32m'
BLUE='\\033[0;34m'
if [ \"\$EUID\" -ne 0 ]; then 
	echo -e \${RED}\"Please run as root\"
	exit
fi
PACKAGEERROR=0
echo \"Checking Dependancies\"
echo \"=====================\"
if [ \$(which rsync 2>/dev/null) ]; then
	echo -e \${GREEN}\$(rsync --version | head -1)
else
	echo -e \${RED}\"rsync not found\"
	PACKAGEERROR=1
fi
if [ \$(which tar 2>/dev/null) ]; then
	echo -e \${GREEN}\$(tar --version | head -1)
else
	echo -e \{RED}\"tar not found\"
	PACKAGEERROR=1
fi
if [ \$(which gpg 2>/dev/null) ]; then
	echo -e \${GREEN}\$(gpg --version | head -1)
else
	echo -e \${RED}\"gpg not found\"
	PACKAGEERROR=1
fi
if [ \$(which pv 2>/dev/null) ]; then
	echo -e \${GREEN}\$(pv --version | head -1)
else
	echo -e \${RED}\"pv not found\"
	PACKAGEERROR=1
fi
if [ \$(which ssh 2>/dev/null) ]; then
	echo -en \${GREEN}
	ssh -V
else
	echo -e \${RED}\"ssh not found\"
	PACKAGEERROR=1
fi
if [ \$PACKAGEERROR = 1 ]; then
	echo -e \${RED}\"Dependances not met\"\${NC}
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
rm /tmp/exclude.txt

#EXIT
echo -e ${NC}"Backup Finished"
exit 0
