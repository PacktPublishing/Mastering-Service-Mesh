# Build Environment for Windows

## Prerequisites

* A decent Windows 10 laptop with minimum 16 GB RAM and Intel Core i7 processor and a preferable minimum 512 GB SSD

## Download VMware Player or Workstation Pro

Download either VMware Player or VMware Workstation Pro

* Since, we are using only one VM - you can download VMware Player which is free and non-expiring for personal use. Download it from [here](https://my.vmware.com/en/web/vmware/free#desktop_end_user_computing/vmware_workstation_player/15_0)

* Download try and buy VMware Workstation Pro for Windows [https://www.vmware.com/products/workstation-pro.html](https://www.vmware.com/products/workstation-pro.html). The try and buy is good for only 30 days and then you have to buy a license. 

Note: 

* VMware Workstation allows you to run multiple VMs in same machine whereas you can only run one VM using VMware Player.

* You may have a preference for Oracle Virtual Box and you can use it instead of VMware Player or VMware Workstation. I have not tested the VM on Virtual Box.

Install either VMware Player or VMware Workstation on your Windows 10 Machine.

After installation of the VMware software, set the NAT `vmnet` subnet so that the VM can access the internet.

Complete one of the following if using VMware WorkStation or VMware Player.

### Set Network Address VMware Workstation

* Go to `Edit` ⇨ `Virtual Network Editor`

* Select `vmnet8` and if necessary hit `Change Settings` to make changes.

Make sue that the subnet IP for vmnet8 is set to `192.168.142.0`. 

Note: If `vmnet8` network is not set to `192.168.142.0`, you will not be able to access internet from inside the VM and hence the exercises will not work.

### Set Network Address VMware Player

VMware Player GUI does not give an option to modify `vmnet8` network address. After installation, open a command line window `cmd` and type `ipconfig /all` and you should see `vmnet8`.

```
Ethernet adapter VMware Network Adapter VMnet8:

   Connection-specific DNS Suffix  . :
   Description . . . . . . . . . . . : VMware Virtual Ethernet Adapter for VMnet8
   Physical Address. . . . . . . . . : 00-50-56-C0-00-08
   DHCP Enabled. . . . . . . . . . . : No
   Autoconfiguration Enabled . . . . : Yes
   Link-local IPv6 Address . . . . . : fe80::1d5f:2196:60f9:6219%23(Preferred)
   IPv4 Address. . . . . . . . . . . : 192.168.191.1(Preferred)
   Subnet Mask . . . . . . . . . . . : 255.255.255.0
   Default Gateway . . . . . . . . . :
   DHCPv6 IAID . . . . . . . . . . . : 905990230
   DHCPv6 Client DUID. . . . . . . . : 00-01-00-01-24-7C-F2-70-98-FA-9B-0E-0E-F3
   DNS Servers . . . . . . . . . . . : fec0:0:0:ffff::1%1
                                       fec0:0:0:ffff::2%1
                                       fec0:0:0:ffff::3%1
   NetBIOS over Tcpip. . . . . . . . : Enabled
```

In above, the `vmnet8` is set to `192.168.191.1` - The IP address may be different for you.

Follow these commands to set the `vmnet8` subnet address to `192.168.142.0`.

Open Windows `CMD` as Administrator (important).

Press `Win-R`, Type `cmd` and hit `CTRL-SHIFT-Enter` to open `CMD` as administrator.

```
cd "\Program Files (x86)\VMware\VMware Player"
vnetlib.exe -- stop dhcp
vnetlib.exe -- stop nat

cd \ProgramData\VMware
copy vmnetdhcp.conf vmnetdhcp.conf.pre
copy vmnetnat.conf vmnetnat.conf.pre

cd "\Program Files (x86)\VMware\VMware Player"
vnetlib.exe -- set vnet vmnet8 mask 255.255.255.0
vnetlib.exe -- set vnet vmnet8 addr 192.168.142.0
vnetlib.exe -- add dhcp vmnet8
vnetlib.exe -- add nat vmnet8
vnetlib.exe -- update dhcp vmnet8
vnetlib.exe -- update nat vmnet8
vnetlib.exe -- update adapter vmnet8

vnetlib.exe -- set vnet vmnet1 mask 255.255.255.0
vnetlib.exe -- set vnet vmnet1 addr 192.168.136.0
vnetlib.exe -- add dhcp vmnet1
vnetlib.exe -- add nat vmnet1
vnetlib.exe -- update dhcp vmnet1
vnetlib.exe -- update nat vmnet1
vnetlib.exe -- update adapter vmnet1

vnetlib.exe -- start dhcp
vnetlib.exe -- start nat
```

Check `ipconfig /all` and you should see `vmnet8` Ip address set to `192.168.142.1`


## Download 7z software 

If you do not have 7z installed on your machine, download 7z from [here](https://www.7-zip.org/download.html) and install 7z software

## Download base VM

Download base VM image from this link: https://7362.me/vm.tar.7z to a folder of your choice.

### Launch 7z software

Select the folder and `vm.tar.7z` file and click `Extract`.

## Start VM

Navigate to the folder where vm was extracted. Right click `kube01.vmx` and Click Open with `VMWare Player` or `VMWare Workstation`.

If VM prompts for you to update VMware software, cancel it and if it prompts for you to update vm tools in the VM, cancel it.

## Sanity check

Double click `Terminal`

The user name is `user` and the password is `password`. The `root` password is `password`.

Test Internet connectivity from the VM.

```
dig +search +noall +answer google.com
```

If `vmnet8` subnet was set to `192.168.142.0` and your Windows machine has internet access, you should see the google.com IP addresses resolved from the above. 

You are ready to install Kubernetes in your environment.

After making your base VM working, go [back](/README.md).

