#!/bin/sh
# Author: William Lam
# Website: www.virtuallyghetto.com
# Product: VMware ESXi
# Description: Simple script to pull down CoreOS image & run on ESXi
# Reference: http://www.virtuallyghetto.com/2014/07/how-to-quickly-deploy-coreos-on-esxi.html

# CoreOS ZIP URL
CORE_OS_DOWNLOAD_URL=http://stable.release.core-os.net/amd64-usr/current/coreos_production_vmware_insecure.zip

# Path of Datastore to store CoreOS
DATASTORE_PATH=/vmfs/volumes/datastore1

# VM Network to connect CoreOS to
VM_NETWORK="VM Network"

# Name of VM
VM_NAME=CoreOS2

## DOT NOT EDIE BYOND HERE ##

#add DNS
if esxcli network ip dns server list | grep -q 8.8.8.8 
then 
   echo "Google DNS present";
else
   echo "adding Google DNS to make wget work";
   esxcli network ip dns server add -s 8.8.8.8
fi

# Creates CoreOS VM Directory and change into it
mkdir -p ${DATASTORE_PATH}/${VM_NAME}
cd ${DATASTORE_PATH}/${VM_NAME}

# Download CoreOS 
wget ${CORE_OS_DOWNLOAD_URL}

# Unzip CoreOS & remove file
unzip coreos_production_vmware_insecure.zip
rm -f coreos_production_vmware_insecure.zip

# Convert VMDK from 2gbsparse from hosted products to Thin 
vmkfstools -i coreos_production_vmware_insecure_image.vmdk -d thin coreos.vmdk

# Remove the original 2gbsparse VMDKs
rm coreos_production_vmware_insecure_image*.vmdk

# Update CoreOS VMX to reference new VMDK
sed -i 's/coreos_production_vmware_insecure_image.vmdk/coreos.vmdk/g' coreos_production_vmware_insecure.vmx

# Update CoreOS VMX w/new VM Name
sed -i "s/displayName.*/displayName = \"${VM_NAME}\"/g" coreos_production_vmware_insecure.vmx

# Update CoreOS VMX to map to VM Network
echo "ethernet0.networkName = \"${VM_NETWORK}\"" >> coreos_production_vmware_insecure.vmx

# Register CoreOS VM which returns VM ID
VM_ID=$(vim-cmd solo/register ${DATASTORE_PATH}/${VM_NAME}/coreos_production_vmware_insecure.vmx)
#look up just to ensure there is not already exists
VM_ID=$(vim-cmd vmsvc/getallvms | grep ${VM_NAME} | cut -d ' ' -f 1)

# Upgrade CoreOS Virtual Hardware from 4 to 8
vim-cmd vmsvc/upgrade ${VM_ID} vmx-08

# enable hypervisor support
echo "vhv.enable = \"TRUE\"" >> coreos_production_vmware_insecure.vmx

vim-cmd vmsvc/power.shutdown  ${VM_ID}

# PowerOn CoreOS VM
vim-cmd vmsvc/power.on ${VM_ID}

# Reset CoreOS VM to quickly get DHCP address
vim-cmd vmsvc/power.reset ${VM_ID}

echo "#connect using the shipped insecure key"
echo "ssh -i insecure_ssh_key core@IP-ADDRESS-OF-COREOS-VM"
