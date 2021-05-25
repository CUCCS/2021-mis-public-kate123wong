#!/usr/bin/env bash

#VER="19.07.5" # openwrt version
VER="15.05.1"
VDI_BASE="openwrt-x86-64-combined-squashfs.vdi"

shasum -c img.sha256.sum  
  #kate:
  # -c  从文件中读取SHA1 的校验值并予以检查
  # -q  don't print OK for each successfully verified file （kali里有该参数，ubuntu16.4里无改参数）
  # 在ubuntu里，如果加上-q，则每次该命令会执行出错，从而无论本地是否已经下载过下面的镜像，都会重新下载。
  # 标准输出重定向到 /dev/null , 2表示标准错误输出，重定向到 &1 ，1表示标准输出。即：标准错误输出也重定向到 /dev/null
if [[ $? -ne 0 ]];then
  # kate:
  # $? 最后运行的命令执行代码的返回值。即shasum的返回值。 
  # -ne ： 不等于
  # shasum执行成功返回0

  # 下载固件
  wget "https://archive.openwrt.org/chaos_calmer/15.05.1/x86/64/openwrt-15.05.1-x86-64-combined-ext4.img.gz" -O openwrt-x86-64-combined-squashfs.img.gz

  # wget https://downloads.openwrt.org/releases/$VER/targets/x86/64/openwrt-$VER-x86-64-combined-squashfs.img.gz -O openwrt-x86-64-combined-squashfs.img.gz
  # kate:
  # wget : 非交互式的网络文件下载工具
  # -O : 将文档写入 FILE/重命名
  # 若官方网站链接发生变化，可以在google搜索文件名。

  # 解压缩
  gzip -d openwrt-x86-64-combined-squashfs.img.gz
  # gzip -d openwrt-x86-64-combined-squashfs.img.gz
  # kate:
  # gzip : Compress or uncompress FILEs
fi

shasum -c vdi.sha256.sum
if [[ $? -ne 0 ]];then
  # img 格式转换为 Virtualbox 虚拟硬盘格式 vdi
  VBoxManage convertfromraw --format VDI openwrt-x86-64-combined-squashfs.img "$VDI_BASE"
  # 新建虚拟机选择「类型」 Linux / 「版本」Linux 2.6 / 3.x / 4.x (64-bit)，填写有意义的虚拟机「名称」
  # 内存设置为 256 MB
  # 使用已有的虚拟硬盘文件 - 「注册」新虚拟硬盘文件选择刚才转换生成的 .vdi 文件


  if [[ $? -eq 1 ]];then
    # 上述代码执行失败，则执行下述代码：将源img镜像拷贝一份，并给其一个新的名字。
    # ref: https://openwrt.org/docs/guide-user/virtualization/virtualbox-vm#convert_openwrtimg_to_vbox_drive
    dd if=openwrt-x86-64-combined-squashfs.img of=openwrt-x86-64-combined-squashfs-padded.img bs=128000 conv=sync
    # dd ：用指定大小的块拷贝一个文件，并在拷贝的同时进行指定的转换
    # if=文件名：输入文件名
    # of=文件名：输出文件名
    # bs=bytes：同时设置读入/输出的块大小为bytes个字节。
    # conv=conversion：用指定的参数转换文件。
    # sync：将每个输入块填充到ibs个字节，不足部分用空（NUL）字符补齐。

    VBoxManage convertfromraw --format VDI openwrt-x86-64-combined-squashfs-padded.img "$VDI_BASE"
     # This command converts a raw disk image to an Oracle VM VirtualBox Disk Image (VDI) file.
  fi
fi

# 创建虚拟机
VM="openwrt-demo"
# VBoxManage list ostypes
if [[ $(VBoxManage list vms | cut -d ' ' -f 1 | grep -w "\"$VM\"" -c) -eq 0 ]];then
    # kate :
    # VBoxManage list vms : 列出所有的虚拟机

    # cut : Print selected parts of lines from each FILE to standard output.
    # -d : 指定分隔符
    # -f : 选取分割后的第一个

    # grep : 在每个 FILE 或是标准输入中查找 PATTERN。默认的 PATTERN 是一个基本正则表达式(缩写为 BRE)
    # -w : 强制匹配
    # -c : 只打印匹配的行数

    # 本行含义：如果版本为“openwrt-19.07.5”的虚拟机的个数为0，则继续往下执行：
  echo "vm $VM not exsits, create it ..."
  VBoxManage createvm --name $VM --ostype "Linux26_64" --register
    # VBoxManage createvm --name $VM --ostype "Linux26_64" --register --groups "/IoT"
    # VBoxManage createvm : 创建并注册一个虚拟机。 
    # --name : 指定虚拟机的名称为：openwrt-19.07.5
    # --ostype : 指定虚拟机的系统类型为：Linux26_64
    
  # 创建一个 SATA 控制器
  VBoxManage storagectl "$VM" --name "SATA" --add sata --controller IntelAHCI
  # 向该控制器安装一个「硬盘」
  ## --medium 指定本地的一个「多重加载」虚拟硬盘文件
  VBoxManage storageattach "$VM" --storagectl "SATA" --port 0 \
    --device 0 --type hdd --medium "$VDI_BASE"

  VBoxManage storagectl "$VM" --name "SATA" --remove

  # 将目标 vdi 修改为「多重加载」
  VBoxManage modifymedium disk --type multiattach "$VDI_BASE"
  # 虚拟磁盘扩容
  VBoxManage modifymedium disk --resize 10240 "$VDI_BASE"

  VBoxManage storagectl "$VM" --name "SATA" --add sata --controller IntelAHCI
  VBoxManage storageattach "$VM" --storagectl "SATA" --port 0 \
    --device 0 --type hdd --medium "$VDI_BASE"

  # 启用 USB 3.0 接口
  VBoxManage modifyvm "$VM" --usbxhci on
  # 修改虚拟机配置
  ## --memory 内存设置为 256MB
  ## --vram   显存设置为 16MB
  VBoxManage modifyvm "$VM" --memory 256 --vram 16

  # ref: https://docs.oracle.com/en/virtualization/virtualbox/6.1/user/settings-display.html
  # VMSVGA: Use this graphics controller to emulate a VMware SVGA graphics device. This is the default graphics controller for Linux guests.
  VBoxManage modifyvm "$VM" --graphicscontroller vmsvga

  # CAUTION: 虚拟机的 WAN 网卡对应的虚拟网络类型必须设置为 NAT 而不能使用 NatNetwork ，无线客户端连入无线网络后才可以正常上网
  ## 检查 NATNetwork 网络是否存在
  # natnetwork_name="NatNetwork"
  # natnetwork_count=$(VBoxManage natnetwork list | grep -c "$natnetwork_name")
  # if [[ $natnetwork_count -eq 0 ]];then
  #   VBoxManage natnetwork add --netname "$natnetwork_name" --network "10.0.2.0/24" --enable --dhcp on
  # fi

  ## 添加 Host-Only 网卡为第 1 块虚拟网卡
  ## --hostonlyadapter1 第 1 块网卡的界面名称为 vboxnet0
  ## --nictype1 第 1 块网卡的控制芯片为 Intel PRO/1000 MT 桌面 (82540EM)
  ## --nic2 nat 第 2 块网卡配置为 NAT 模式
  VBoxManage modifyvm "$VM" --nic1 "hostonly" --nictype1 "82540EM" --hostonlyadapter1 "vboxnet0"
  VBoxManage modifyvm "$VM" --nic2 nat 
fi