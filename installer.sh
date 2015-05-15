#!/bin/sh
CURRENT_FILE=1
AMOUNT_FILES=1
RAWURL='http://node-arm.herokuapp.com/node_latest_armhf.deb'
TMP_PATH=/tmp
IFACE=eth0
APT='avahi-daemon cups python-cups printer-driver-gutenprint system-config-printer-udev python-pip cups-pdf pip install git python-daemon ink samba preload logrotate'

if [[ $(id -u) -ne 0 ]] ; then echo "Please run as root" ; exit 1 ; fi

check_dep () {

                if [ "$(which pip)" ]; then
                    echo "pip found, trying to update it"
                    pip install -U pip
                else
                    apt-get -q install python-pip
                    pip install -U pip
				fi
	
				if [ "$(which npm)" ]; then
                    echo "npm found, trying to update it"
                    npm upgrade npm -g
				else
                    echo "Downloading $1 [$CURRENT_FILE/$AMOUNT_FILES]"
                    wget -q -P $TMP_PATH $RAWURL
                    [ $? -ne 0 ] && {
                        echo "Downloading failed. Abort."
                        exit 1
                    }
                        CURRENT_FILE=$(($CURRENT_FILE + 1))
				        dpkg -i $TMP_PATH/node_latest_armhf.deb
                        npm upgrade npm -g
}
	
install_apps () {

                for pkg in $APT; do

                    if [ "dpkg-query -W $pkg | awk {'print $1'} = """ ]; then
                        echo "$pkg is already installed"
                    else
                        apt-get install -y $pkg
                        echo "Successfully installed $pkg"
                    fi

                done

                if [ "$(which cloudprint)" ]; then
				    echo "cloudprint found, trying to update it"
				    pip install cloudprint --upgrade
			    else
				    pip install cloudprint
			    fi

			    if [ "$(which mintr)" ]; then
				    echo "mintr found, trying to update it"
				    npm upgrade mintr -g
			    else
				    npm install mintr -g
			    fi

			    if [ "$(which git)" ]; then
				    echo "git found"
				    if [ -d "/usr/bin/airprint" ]; then
					    cd /usr/bin/airprint
					    git pull
				    else
					    git clone https://github.com/tjfontaine/airprint-generate /usr/bin/airprint
			    else
				    apt-get -q -y git
				    git clone https://github.com/tjfontaine/airprint-generate /usr/bin/airprint
			    fi
}

make_dir () {

			    mkdir -p /storage/pdf 
			    chmod 666 /storage/pdf
	    
			    mv mime/* /usr/share/cups/mime/
			    mv files/* /usr/bin/
	
			    chmod +x /usr/local/bin/cups-pdf-renamer
			    chmod +x /usr/bin/inklog
			    chmod +x /usr/bin/mservice
			    chmod +x /usr/bin/airprint/airprint-generate.py
			    chmod 755 /usr/local/bin/cups-pdf-renamer

			    chown root:lpadmin /storage/pdf
			    chown root:lpadmin /usr/local/bin/cups-pdf-renamer
}

make_config () {

    			if [ -f /etc/cups/cups-pdf.conf ]; then
	
	    			sed -i "s|Out ${HOME}/PDF|Out /storage/pdf|" /etc/cups/cups-pdf.conf
		    		sed -i "s|Listen localhost:631|Listen *:631|" /etc/cups/cupsd.conf
			    	sed -i "s||Allow alln|g" /etc/cups/cupsd.conf
				    sed -i "s|Shared No|Shared Yes|g" /etc/cups/printers.conf
				    sed -i -e "s|BrowseAddress|BrowseAddress $(ifconfig $IFACE | awk '/inet addr/{print substr($2,6)}') n#BrowseAddress|" /etc/cups/cupsd.conf
				    sed -i "s|#PostProcessing|PostProcessing /usr/local/bin/cups-pdf-renamer|" /etc/cups/cups-pdf.conf
				    echo  -e "nServerName $name" >> /etc/cups/cupsd.conf

			    else
				    echo "File does not exists"
			    fi

			    cupsctl --share-printers --remote-admin --remote-printers
    			lpoptions -d PDF -o printer-is-shared=true

    			echo "@reboot /usr/bin/printlog -i" >>/var/spool/cron/crontabs/root
	    		echo "0 21 28-31 * * [ $(date -d +1day +%d) -eq 1 ] && /usr/bin/inklog -m" >>/var/spool/cron/crontabs/root

    			if [ -f /etc/samba/smb.conf ]; then
	    			cat >"/etc/samba/smb.conf" <<EOT
[PDF]
comment=
path=/storage/pdf
guest ok=yes
browseable=yes
create mask=0666
directory mask=0666
EOT

			    cloudprint -c
}

reload_services () {

				systemctl reload cups
				systemctl reload avahi-daemon
				systemctl reload samba
}

check_dep
install_apps
make_dir
make_config
reload_services
clear
#reboot