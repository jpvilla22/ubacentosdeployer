#!/bin/bash

# Execution case with no parameters
if [ -z $3 ]; then
		echo "UBA VMs Provisioning CentOS7 Deployer Script v0.9"
		echo
		echo "Please complete with desired IP, Hostname and root password"
		echo
		echo "       example: ubacentosdeployer.sh 10.10.10.200 server rootpw"
		echo
		echo "- This shellscript fully depends on having python v2.7.x" 
		echo "  installed on your system"
		echo "- Requires paramiko python library (pip install paramiko)"
		echo "- It also calls to a python script called sshpt.py to do all the magic" 
		echo "  (tested with sshpt v.1.2.0 on https://code.google.com/archive/p/sshpt/)"
		echo
		echo "(Copyleft) JPV 2020"
		echo "latest version at: https://github.com/jpvilla22/ubacentosdeployer"
        exit 2
fi

# Configuration variables - parameters
ipdepl=$1 # Desired final IP of the VM deployment
hndepl=$2 # Desired hostname of the VM deployment
pwdepl=$3 # Desired final root password

# Other variables - all your tinkering should be here, if this script is gonna be truly useful 
tmppw="defaultrootpassword" # Temporary default root password of the template
dynip="10.10.10.10" # Unique temporary IP assigned by your DHCP server on provisioning VLAN upon template spawn.
ipcfg="/etc/sysconfig/network-scripts/ifcfg-ens192" # Location of ifcfg file on the template
ethname="ens192" # Name of ethernet device on NAME section of the syconfig file   
ethdevice="ens192" # Ethernet device on DEVICE section of the sysconfig file
dgway="10.10.10.1" # Desired default gateway on sysconfig file
dns1="8.8.8.8" # Desired dns config 1 on sysconfig file
dns2="8.8.4.4" # Desired dns config 2 on sysconfig file
 
# Proper execution of the script
echo "UBA VMs Provisioning CentOS7 Deployer Script v0.9 - (c)JPV 2020"
echo "---------------------------------------------------------------"
echo
echo You have entered the following values
echo IP: $ipdepl 
echo Hostname: $hndepl
echo Password: $pwdepl
echo 

# Set temporary IP to connect on a temporary local file for later use
echo $dynip > host.txt

# Put a specific mkdir instruction on a temporary local file for later use
echo "mkdir ~/.ssh" > mkdirssh.txt

# Set authorized_keys to a temporary local file for later use
echo "ssh-rsa use your own keys        \
you can break it with these backlashes \
for proper script presentation         \
ldjd39edf9f9f9/ user@host" > authorized_keys
echo "ssh-rsa this is another example key                   \
you can generate keys on your own workstation by running:   \
ssh-keygen -q -N ""    (leave default answer)               \
then look for a file (.ssh/id_rsa.pub) on your disk         \
and paste it here - no ssh-copy-id needed with this method  \
kdkdjdjdjdjddi/ user2@host2" >> authorized_keys

# Set a proper yum.conf on a temporary local file for our purposes
cat >yum.conf <<EOL
# Config added automatically by UBA CentOS7 Deployer (c)2020 JPV
[main]
cachedir=/var/cache/yum/\$basearch/\$releasever
keepcache=0
debuglevel=2
logfile=/var/log/yum.log
exactarch=1
obsoletes=1
gpgcheck=1
plugins=1
installonly_limit=5
bugtracker_url=http://bugs.centos.org/set_project.php?project_id=23&ref=http://bugs.centos.org/bug_report_page.php?category=yum
distroverpkg=centos-release
#  This is the default, if you make this bigger yum won't see if the metadata
# is newer on the remote and so you'll "gain" the bandwidth of not having to
# download the new metadata and "pay" for it by yum not having correct
# information.
#  It is esp. important, to have correct metadata, for distributions like
# Fedora which don't keep old packages around. If you don't like this checking
# interupting your command line usage, it's much better to have something
# manually check the metadata once an hour (yum-updatesd will do this).
# metadata_expire=90m

# PUT YOUR REPOS HERE OR IN separate files named file.repo
# in /etc/yum.repos.d
EOL

#Here we craft a proper execution script to deliver to the host
cat >execute.txt <<EOL
echo -----------
echo Substep 4.1 - Setting root password
echo
echo $pwdepl | passwd root --stdin
echo -----------
echo Substep 4.2 - Setting IP Config 
grep HWADDR $ipcfg > /root/hwaddr.txt
echo "#Config added automatically by UBA CentOS7 Deployer (c)2020 JPV" > $ipcfg
cat /root/hwaddr >> $ipcfg
echo >> $ipcfg
echo NAME=$ethname >> $ipcfg
echo DEVICE=$ethdevice >> $ipcfg
echo ONBOOT=yes >> $ipcfg
echo USERCTL=no >> $ipcfg
echo PEERDNS=yes >> $ipcfg
echo IPV6INIT=no >> $ipcfg
echo IPV6_AUTOCONF=no >> $ipcfg
echo BOOTPROTO=none >> $ipcfg
echo IPADDR=$ipdepl >> $ipcfg
echo PREFIX=24 >> $ipcfg
echo GATEWAY=$dgway >> $ipcfg
echo DNS1=$dns1 >> $ipcfg
echo DNS2=$dns2 >> $ipcfg
echo DEFROUTE=yes >> $ipcfg
echo "check_link_down() {" >> $ipcfg
echo " return 1;" >> $ipcfg
echo "}" >> $ipcfg
echo -----------
echo Substep 4.3 - Setting Hostname to $hndepl
hostnamectl set-hostname $hndepl
echo -----------
echo Substep 4.4 - Installing nano editor 
echo
yum install nano -y
echo -----------
echo Substep 4.5 - Installing EPEL repo
echo 
yum install epel-release -y
echo -----------
echo Substep 4.6 - Updating all packages  
echo 
yum update -y
echo
echo -----------
echo Substep 4.7 - Setting minimalistic /etc/hosts
echo "127.0.0.1   localhost" > /etc/hosts
echo -----------
echo 

EOL

#Actual execution of all steps
echo Executing all commands 
echo
echo STEP 1: Make .ssh dir on root folder before authorized_keys conf copy
python sshpt.py -u root -P $tmppw -f host.txt -c mkdirssh.txt -x -r 
echo ENDING STEP 1
echo 
echo STEP 2: Installing authorized_keys
python sshpt.py -u root -P $tmppw -f host.txt -c authorized_keys -D /root/.ssh/ 
echo ENDING STEP 2
echo
echo STEP 3: Replacing botched yum.conf file
python sshpt.py -u root -P $tmppw -f host.txt -c yum.conf -D /etc/ 
echo ENDING STEP 3 
echo
echo STEP 4: Executing final deploy script on the host
echo
python sshpt.py -u root -P $tmppw -f host.txt -c execute.txt -x -r 
echo ENDING STEP 4
echo

# Final Step: Reboot the host to apply all changes
echo
echo STEP 5: REBOOTING HOST -- bye!!!! 
echo         Remember that this host will be at $ipdepl when rebooted
echo
python sshpt.py -u root -P $pwdepl -f host.txt "reboot"
echo ENDING DEPLOYMENT

# Clean up 
rm mkdirssh.txt
rm authorized_keys
rm host.txt
rm yum.conf
rm execute.txt

# Add to your local ssh config - Not really needed
#echo "Host $hndepl" >> ~/.ssh/config
#echo "    Hostname $ipdepl" >> ~/.ssh/config
#echo "    User root" >> ~/.ssh/config
