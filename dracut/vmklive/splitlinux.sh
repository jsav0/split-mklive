#!/bin/sh -x
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
# IMPORTANT: This script is run when booting the ISO - not when building it!
#

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh

# Further down we hardcode "lxc". For as long as that is the case we cannot
# dynamically assign GROUPNAME here.
#GROUPNAME=$(getarg live.splitlinuxgroup)

[ -z "$GROUPNAME" ] && GROUPNAME=lxc

chroot ${NEWROOT} groupadd $GROUPNAME

# Enable certain sudo permission for lxc-group.
if [ -f ${NEWROOT}/etc/sudoers ]; then
    echo "
%${GROUPNAME} ALL=(ALL) NOPASSWD:        /usr/bin/lxc-info --state --no-humanize --name *, \\
                                /usr/bin/lxc-start --name *, \\
                                /usr/bin/lxc-attach --name *" >> ${NEWROOT}/etc/sudoers
fi


# "Unlock'n'load"
echo 'Waiting for crypto_LUKS partition to unlock.'

total=0
choice=-1
retries=0
while [ $choice -lt 0 -o $choice -gt $total ] ; do
    sleep 1s
    crypto_devices=`lsblk --noheadings --list --paths --output FSTYPE,NAME,SIZE,UUID | sed --silent 's#^crypto_LUKS \+##p'`
    # `wc` is not available, hence this awk command will count the lines.
    total=`echo -n "$crypto_devices" | awk 'END {print NR}'`

    if [ $total -ge 2 ] ; then
        echo ' Multiple crypto_LUKS devices found.'
        echo ' Please select the one holding the Split horde (or skip by pressing 0).'
        echo
        echo ' 0) Boot without decrypting any device'
        # `nl` is not available, hence this awk command will number the lines.
        echo "$crypto_devices" | awk '{print " "NR") "$0}'
	echo
        echo -n 'Your choice: '

        # -sn1 allows to input a single character without having to confirm by
        # pressing Enter. It is bash-specific, however. In case it fails, the
        # alternative read is used as fallback.
        read -sn1 choice 2>/dev/null || read choice
    else
        if [ $total -eq 0 ] ; then
	    case ${retries} in
	    	0)
	    		echo -n ' No crypto_LUKS found yet. Retrying ...'
	    		;;
	    	11)
                        echo
	    		echo " Failed. Will boot without decrypting any device."
		        choice=0
			;;
	    	*)
	    		echo -n "..${retries}"
	    		;;
	    esac
	    retries=`expr $retries + 1`
        else
            echo ' Only one crypto_LUKS device found. Using it.'
            choice=$total
        fi
    fi
done

if [ $choice -eq 0 ] ; then
    echo 'Booting without decrypting any device.'
else
    uuid_of_luks_device=`echo "$crypto_devices" | sed --silent "${choice}p" | awk '{ print $3 }'`
    cryptsetup open /dev/disk/by-uuid/${uuid_of_luks_device} split

    echo 'Mounting "horde" logical volume of "split" volume group (if both exist).'
    lvm vgchange --activate y split &&
        mount /dev/mapper/split-horde /sysroot/var/lib/lxc

    echo 'Swapping on "swap" logical volume of "split" volume group (if both exist).'
    uuid_of_swap_device=`lsblk --noheadings --list --output FSTYPE,NAME,UUID | sed --silent 's#^swap \+split-swap \+##p'`
    [ -z $uuid_of_swap_device ] || swapon -U ${uuid_of_swap_device}
fi

### DEBUG ONLY
#echo
#echo 'Starting bash for debugging. Just `exit` when ready.'
#bash
### DEBUG ONLY


#echo 'Configuring host to use Tor as SOCKS_PROXY.'
#chroot ${NEWROOT} sh -c '
#mkdir -p /etc/xbps.d &&
#    cp /usr/share/xbps.d/*-repository-*.conf /etc/xbps.d/ &&
#    sed -i "s|https://alpha.de.repo.voidlinux.org|http://lysator7eknrfl47rlyxvgeamrv7ucefgrrlhk7rouv3sna25asetwid.onion/pub/voidlinux|g" /etc/xbps.d/*-repository-*.conf
#
#cat - <<EOF > /etc/profile.d/socksproxy.sh
##!/bin/sh
#export SOCKS_PROXY="socks5://172.18.0.1:9057"
#EOF'


echo 'Adding skel .xinitrc script that executes the containerized one.'
echo '# clear-env avoids leaking any env info into the container.
# However, since clear-env (and login) unset $DISPLAY, the variable has to be
# passed manually, so the container knows which one to use.

/bin/sudo lxc-attach --name "${USER}" --clear-env -- \
	su "${USER}" --login \
		--command="DISPLAY=${DISPLAY} . ${HOME}/.xinitrc" \
		2>&1 > "${HOME}/`basename $0`.log"
' > ${NEWROOT}/etc/skel/.xinitrc


echo 'Adding users to the host system.'
echo ' For each LXC container a matching user of the same name is created. All those
       users are added to the "lxc" group.'
echo ' When a member user of this group logs in and there is yet again the same user
       name defined *within* the container, Split will run *their* .xinitrc using
       their user id.'
chroot ${NEWROOT} sh -c '
	cd /var/lib/lxc/ &&
            for u in * ; do
	        useradd --create-home --groups lxc "${u}"
	        shadow_entry=`grep -wE "^${u}:" /var/lib/lxc/${u}/rootfs/etc/shadow`
	        sed -i "s#^${u}:.*#${shadow_entry}#g" /etc/shadow
	    done
'


echo 'Adding profile.d script that forks host logins to container-logins.'
echo ' This is done by attaching the container and loading its .xinitrc, which will'
echo ' typically call a graphical application (ie. a window manager).'
if [ -x ${NEWROOT}/sbin/lxc-info ]; then
echo 'if [ -z $DISPLAY ] ; then
        if groups "${USER}" | grep --quiet --fixed-strings --word-regexp lxc ; then
                XDG_VTNR=${XDG_VTNR:-`fgconsole`}
                DPNR=`expr ${XDG_VTNR} - 1`
                CONTAINER=$USER
                container_state=`sudo lxc-info --state --no-humanize --name "${CONTAINER}"`

                case "${container_state}" in
                        "STOPPED")
                                sudo lxc-start --name "${CONTAINER}" && exec xinit -- :${DPNR} vt${XDG_VTNR}
                                ;;
                        "RUNNING")
                                # For this to work, put at least the following into the ~/.xinitrc on the hostsystem:
                                # /bin/sudo lxc-attach --name "${USER}" dwm
                                exec xinit -- :${DPNR} vt${XDG_VTNR} &> "${HOME}/.xsession.log" ||
                                    echo "xinit failed. Dropping to a shell." && bash
                                ;;
                esac
        fi
fi' > ${NEWROOT}/etc/profile.d/fork_into_container.sh
fi
