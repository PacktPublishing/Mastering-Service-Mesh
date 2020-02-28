# Build Environment for MacBook

## Prerequisites

* MacBook Pro (2015) onwards with 16 GB RAM, Intel Core i7 Processor with 4 cores and a preferable minimum 512 GB SSD

## Download VMware Fusion 11.5 or later

* There is no VMware Player for MacBook. The only option is to use VMware Fusion 11.x. You can install a trial copy of the VMware Fusion for 30 day to go through the exercises.

You can download VMware Fusion 11.x from [here](https://www.vmware.com/products/fusion/fusion-evaluation.html)

Note: 

* You may have a preference for Oracle Virtual Box and you can use it instead of VMware Fusion. I have not tested the VM on Virtual Box.

Install VMware Fusion on your MacBook.

After installation of the VMware Fusion, set the NAT `vmnet` subnet so that the VM can access the internet.

### Set Network Address

Open a command line shell in your MacBook and run following commands.

```
$ sudo -i 
<type your password>

# vi /Library/Preferences/VMware\ Fusion/networking
```

Modify line having `VMNET_8_HOSTONLY_SUBNET` to match as shown below

```
 anwwer VMNET_8_HOSTONLY_SUBNET 192.168.142.0
```

Save the file.

#### Fix Gateway for vmnet8

Modify file `/Library/Preferences/VMware\ Fusion/vmnet8/nat.conf`

```
# vi /Library/Preferences/VMware\ Fusion/vmnet8/nat.conf
```

And change `ip` and `netmask` after comment

```
# NAT gateway address
ip = 192.168.142.2
netmask = 255.255.255.0
```

#### Restart the network
```
# cd /Applications/VMware\ Fusion.app/Contents/Library/

# ./vmnet-cli --configure
# ./vmnet-cli --stop
# ./vmnet-cli --start
```

## Download 7z software 

Install free `7z Unarchiver` from Apple App Store

## Download base VM

Download base VM image from this link: https://7362.me/vm.tar.7z to a folder of your choice.

### Launch 7z software

Select the folder and `vm.tar.7z` file and double click to extract files.

## Start VM

Navigate to the folder where vm was extracted. Right click `kube01.vmx` and Click Open With `VMWare Fusion`.

Wait for the VM to start.

## Sanity check

Double click `Terminal`

The user name is `user` and the password is `password`. The `root` password is `password`.

Test Internet connectivity from the VM.

```
dig +search +noall +answer google.com
```

If `vmnet8` subnet was set to `192.168.142.0` and your MacBook has internet access, you should see the google.com IP addresses resolved from the above. 

You are ready to install Kubernetes in your environment.

After making your base VM working, go [back](/README.md).

