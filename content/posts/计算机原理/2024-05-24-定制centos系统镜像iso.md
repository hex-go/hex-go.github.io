---
title: 定制centos镜像iso
categories:
  - 计算机原理
tags:
  - 计算机原理
  - Draft
date: '2024-05-24 08:57:45'
top: false
draft: true
comments: true
description: 定制centos镜像
---


## 准备工作
操作系统镜像：CentOS-8.2.2004-x86_64-dvd1.iso 
刻盘工具：Rufus
```bash 

curl -o /etc/yum.repos.d/CentOS-Base-Aliyun.repo http://mirrors.aliyun.com/repo/Centos-8.repo
yum clean all && yum makecache
yum install createrepo mkisofs isomd5sum squashfs-tools

# Installed:
#   createrepo_c-0.17.2-3.el8.x86_64
#   createrepo_c-libs-0.17.2-3.el8.x86_64 
#   drpm-0.4.1-3.el8.x86_64 
#   genisoimage-1.1.11-39.el8.x86_64 
#   isomd5sum-1:1.2.3-3.el8.x86_64
#   libmodulemd-2.13.0-1.el8.x86_64
#   libusal-1.1.11-39.el8.x86_64
# Complete!
 
mkdir /root/centos8.2
rsync -a /mnt/ /root/centos8.2/
cp ks.cfg centos8.2/isolinux/
```

```bash
vi /root/centos8.2/isolinux/isolinux.cfg
#添加菜单
label autoinstall
    menu label ^Automated Installation
    kernel vmlinuz
    append initrd=initrd.img inst.stage2=hd:LABEL=CentOS-8-2-2004-x86_64-dvd quiet ks=hd:LABEL=CentOS-8-2-2004-x86_64-dvd:/isolinux/ks.cfg

vi ks.cfg
#定义安装脚本

vi /root/centos8.2/EFI/BOOT/grub.cfg
#添加菜单
search --no-floppy --set=root -l 'CentOS-8-2-2004-x86_64-dvd'

menuentry 'Automated Installation' --class fedora --class gnu-linux --class gnu --class os {
    linuxefi /images/pxeboot/vmlinuz inst.ks=hd:LABEL=CentOS-8-2-2004-x86_64-dvd:/isolinux/ks.cfg inst.stage2=hd:LABEL=CentOS-8-2-2004-x86_64-dvd quiet
    initrdefi /images/pxeboot/initrd.img
}
```
### 关键引导补充内容
```bash
search --no-floppy --set=root -l 'CentOS-8-2-2004-x86_64-dvd'
```
这行命令的作用是在isolinux.cfg文件中使用search命令来设置根目录为包含标签为'CentOS-8-2-2004-x86_64-dvd'的设备。这个命令通常用于指定引导时的根目录，以确保引导程序能够正确找到并加载后续的内核和初始化镜像文件。

在这个命令中：

--no-floppy表示不搜索软盘设备。 --set=root表示将找到的设备设置为根目录。 -l 'CentOS-8-2-2004-x86_64-dvd'表示要搜索包含标签为'CentOS-8-2-2004-x86_64-dvd'的设备。 通过这行命令，引导程序将会在设备中搜索具有指定标签的设备，并将其设置为根目录，以便后续引导过程能够正确进行。

## 制作定制镜像
```bash
genisoimage -v -cache-inodes -joliet-long -R -J -T -V 'CentOS-8-2-2004-x86_64-dvd' -o ../centos8.2-custom-4.iso -c isolinux/boot.cat -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -b images/efiboot.img -no-emul-boot ./

# -v：启用详细模式，显示更多信息。
# -cache-inodes：缓存inode以提高性能。
# -joliet-long -R -J -T：启用Joliet、Rock Ridge和ISO 9660 Level 3的长文件名支持。
# -V 'CentOS8.2'：设置ISO的卷标。
# -o ../centos8.2-custom.iso：指定输出的ISO文件名和路径。
# -c isolinux/boot.cat：包含启动目录的.cat文件。
# -b isolinux/isolinux.bin：指定启动扇区。
# -no-emul-boot：禁止模拟引导。
# -boot-load-size 4：设置引导加载器加载的扇区数。
# -boot-info-table：在ISO的结束处添加一个引导信息表。
# -eltorito-alt-boot：启用El Torito的备用引导记录。
# -b images/efiboot.img：指定EFI启动图像。
# -no-emul-boot：再次禁止模拟引导（可能重复了）。
# ./：指定要包含在ISO中的源目录。
# 这个命令假设源目录./包含了CentOS 8.2的基础ISO内容，以及isolinux和images子目录，这些子目录通常包含启动所需的文件。如果你的源目录结构不同，或者需要添加自定义的ks.cfg和media.repo文件，你需要相应地调整./后的路径。

# 如果你的ks.cfg和media.repo文件与ISO的根目录同级，你可能需要将它们移动到挂载的ISO目录内，或者在创建ISO后，手动将它们添加到ISO的正确位置。如果media.repo是网络安装源的一部分，确保它在你的网络服务器上可用，并在ks.cfg中正确引用。
```

**成功回执**
```
#  99.88% done, estimate finish Tue May 21 16:05:24 2024
# Total translation table size: 1791526
# Total rockridge attributes bytes: 804048
# Total directory bytes: 1206272
# Path table size(bytes): 188
# Done with: The File(s)                             Block(s)    4053625
# Writing:   Ending Padblock                         Start Block 4054673
# Done with: Ending Padblock                         Block(s)    150
# Max brk space used 711000
# 4054823 extents written (7919 MB)
```
**查看生成iso镜像**
```bash
ls ../centos8.2-custom-4.iso
```
## 附录

**示范参考ks.cfg**
```ini
==============================
#platform=x86, AMD64, or Intel EM64T
#version=DEVEL
# Install OS instead of upgrade
install
# Use text mode install
text
# System language
lang en_US
# Keyboard layouts
keyboard us
# Network information
network --bootproto=dhcp
# Root password
rootpw --iscrypted $6$randomencryptedpassword
# System timezone
timezone UTC
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all --initlabel
# Disk partitioning information
part /boot --fstype=&quot;xfs&quot; --size=500
part swap --fstype=&quot;swap&quot; --size=2048
part / --fstype=&quot;xfs&quot; --size=1 --grow
# Reboot after installation
reboot
# System bootloader configuration
bootloader --location=mbr
# Firewall configuration
firewall --enabled --service=ssh
# Package installation
%packages
@^minimal
@core
%end
```
**LiveCD制作镜像参考**
要将CentOS 8打包成一个自动安装镜像，您可以使用LiveCD工具（如livecd-tools）来创建包含自定义Kickstart文件的ISO镜像。以下是实现这一目标的基本步骤：

准备工作：

下载CentOS 8的ISO安装镜像。
准备一个包含自定义Kickstart文件的目录。
创建自定义Kickstart文件（ks.cfg）：

编辑一个包含您自定义安装配置的Kickstart文件。
将Kickstart文件和CentOS 8 ISO镜像放置在同一个目录中。

安装LiveCD工具：

如果您尚未安装LiveCD工具，可以使用以下命令进行安装：
```bash
sudo dnf install livecd-tools
```
创建自动安装ISO镜像：

使用LiveCD工具的livecd-creator命令来创建自动安装ISO镜像，指定Kickstart文件的位置和其他参数。例如：
```bash     
sudo livecd-creator --config=/path/to/your/kickstart/file.ks --fslabel=CentOS8_AutoInstall
```
等待ISO镜像创建完成，您将在指定的目录中找到新的自动安装ISO镜像。

将新创建的ISO镜像刻录到光盘或制作成启动U盘。

使用新的自动安装ISO镜像启动计算机，按照自定义的Kickstart文件中的配置信息进行自动化安装。

通过以上步骤，您可以将CentOS 8打包成一个包含自定义Kickstart文件的自动安装ISO镜像。

## VMware Workstation 16Pro 激活秘钥
vmware16pro许可证密钥最新分享
ZF3R0-FHED2-M80TY-8QYGC-NPKYF
YF390-0HF8P-M81RQ-2DXQE-M2UT6
ZF71R-DMX85-08DQY-8YMNC-PPHV8

## 未成功版,只作为参考
```genisoimage -o CentOS-8.2-custom.iso -J -r -V CentOS8.2 -P /root/centos8.2/
# -o /var/www/html/iso/centos8-stream/CentOS-Stream-8-custom.iso：指定输出的ISO文件路径和名称。
# -J：启用Rock Ridge扩展，这使得ISO支持长文件名和Unix文件属性。
# -r：创建一个可读写的ISO，但通常用于光盘备份，而不是自定义安装ISO。
# -V CentOS8-Stream-Custom：设置ISO的卷标，即在Windows资源管理器或Linux的mount命令中显示的名称。
# /mnt/cdrom：这是要包含在ISO中的源目录，即你之前挂载的ISO或包含自定义内容的目录。
# 如果你想创建一个包含自定义ks.cfg和网络安装源的CentOS 8 Stream ISO，你需要确保/mnt/cdrom目录包含所有必要的内容，例如基础ISO的内容、ks.cfg文件以及指向网络安装源的media.repo文件。如果你的ks.cfg和media.repo文件不在/mnt/cdrom目录下，你需要先将它们复制过去，或者在创建ISO时指定正确的源路径。

# 如果你的ks.cfg和media.repo文件与ISO的根目录同级，你可能需要在创建ISO前将它们移动到挂载的ISO目录内，或者在创建ISO后，手动将它们添加到ISO的正确位置。使用genisoimage时，你可能还需要使用-P选项来保留文件权限和时间戳，确保文件的元数据被正确地包含在ISO中。
```
