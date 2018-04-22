#!/bin/bash

#[IOMMU 1] 01:00.0 VGA compatible controller [0300]: NVIDIA Corporation Device [10de:1b80] (rev a1)
#[IOMMU 1] 01:00.1 Audio device [0403]: NVIDIA Corporation Device [10de:10f0] (rev a1)

# Check with:
# for dp in $(find /sys/kernel/iommu_groups/*/devices/*); do ploc=$(basename $dp | sed 's/0000://'); igrp=$(echo $dp | awk -F/ '{print $5}'); dinfo=$(lspci -nn | grep -E "^$ploc"); echo "[IOMMU $igrp] $dinfo" ; done  

gpu_devid="10de 1b80"
gpu_audio_devid="10de 10f0"
gpu_pci_bus="0000:01:00.0"
gpu_audio_pci_bus="0000:01:00.1"
gpu_modules=("nvidia_drm" "nvidia_modeset" "nvidia" "nvidiafb")
kvm_modules=("kvm_intel" "kvm" "pci_stub" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd" "vfio")

function module {
        local -n arr=$2
        for mod in "${arr[@]}" ; do
		  if [ "$1" == "load" ] ; then
			   if lsmod | grep "$mod" &> /dev/null ; then
			  		echo "Module :$mod is already loaded"
			   else
			  		echo "Loading Module :$mod"
			  		modprobe -q $mod
			   fi
		else
			  if lsmod | grep "$mod" &> /dev/null ; then
			  		echo "Removing module: $mod"
			  		rmmod $mod
			  else
			  		echo "Module :$mod is not loaded"
			  fi
		fi
		sleep 1
	done
} 

# Unbind vga
if [ "$1" == 'unbind' ]; then	
    echo "Unbind GPU"
		
	module "unload" gpu_modules
	module "load" kvm_modules
	
    echo $gpu_devid> /sys/bus/pci/drivers/pci-stub/new_id
	sleep 1
	$(echo $gpu_pci_bus > /sys/bus/pci/devices/$gpu_pci_bus/driver/unbind)
	sleep 1
    echo $gpu_pci_bus > /sys/bus/pci/drivers/pci-stub/bind
	sleep 1	
	echo "Unbind GPU Audio"
    echo $gpu_audio_devid > /sys/bus/pci/drivers/pci-stub/new_id
	sleep 1
    $(echo $gpu_audio_pci_bus > /sys/bus/pci/devices/$gpu_audio_pci_bus/driver/unbind)
	sleep 1
    echo $gpu_audio_pci_bus > /sys/bus/pci/drivers/pci-stub/bind
else
	echo "Bind GPU"
    
	module "unload" kvm_modules
	module "load" gpu_modules
	
	#echo '0000:01:00.0' > /sys/bus/pci/devices/0000\:01\:00.0/driver/bind
    $(echo 1 > /sys/bus/pci/devices/$gpu_pci_bus/remove)
	sleep 1
	echo "Bind GPU Audio"
    $(echo 1 > /sys/bus/pci/devices/$gpu_audio_pci_bus/remove)
	sleep 1
    echo 1 > /sys/bus/pci/rescan
fi