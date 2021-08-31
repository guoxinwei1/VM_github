#!/bin/bash
# V - 2020.8.19
# 如果是向 vim 中粘贴的话，先在末行模式开启粘贴模式避免自动缩进   :set paste

c_re=`rpm -q centos-release | cut -d- -f3`
# 定义当前操作系统发行版的数字变量
ZZ="^(25[0-5]\.|2[0-4][0-9]\.|1[0-9][0-9]\.|[1-9][0-9]\.|[0-9]\.){3}(25[0-4]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[1-9])$"
# 定义 IP 地址的正则表达式
if [ $c_re -ne 6 ] && [ $c_re -ne 7 ]
then
echo "不支持的操作系统！"
exit 1
fi
# 如果不是 CentOS 6 或者 7 则退出
cat <<EOF
本脚本支持CentOS 6/7 单网卡的IP设置
将CentOS 7 的网卡改名为 eth0 
并关闭防火墙和Selinux，配置本地yum源
正常执行完毕需要重启系统生效配置。
请确保配置的IP和VMware的网络配置为同一网段，掩码为24位。
EOF
while :
do
read -p "请输入需要配置的IP地址(不输入则退出脚本):" N_ip
if [ -z "$N_ip" ]
    then
    echo "再见"
    exit
elif [[ $N_ip =~ $ZZ ]]
    then
    break
else
    echo "请检查IP格式"
fi
done

N_mask=`echo "$N_ip" | awk -F "." '{print $1"."$2"."$3}'`
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 << EOF
DEVICE=eth0
NAME=eth0
TYPE=Ethernet
ONBOOT=yes
BOOTPROTO=static
IPADDR=$N_ip
NETMASK=255.255.255.0
GATEWAY=$N_mask.2
DNS1=223.5.5.5
DNS2=$N_mask.2
EOF

rm -rf /etc/yum.repos.d/*
cat > /etc/yum.repos.d/local.repo << EOF
[local]
name=local repo
baseurl=file:///media/cdrom
enabled=1
gpgcheck=0
EOF

umount /dev/sr0 &> /dev/null
[ -d /media/cdrom ] || mkdir /media/cdrom && mount /dev/sr0 /media/cdrom &> /dev/null
if [ $? -ne 0 ]
    then
    echo "检查光驱是否连接"
    exit 1
fi
if [ `grep -c sr0 /etc/fstab` -eq 0 ]
    then
    cat >> /etc/fstab << EOF
/dev/sr0 /media/cdrom iso9660 defaults 0 0
EOF
fi
yum clean all && yum makecache
if [ $? -ne 0 ]
    then
    echo "yum error"
    exit 1
fi

yum -y install lrzsz tree ntpdate
yum -y remove NetworkManager postfix

setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
sed -i 's/#UseDNS yes/UseDNS no/g' /etc/ssh/sshd_config

read -p "当前主机名为：`hostname`   请输入主机名(不输入则不修改)：" h_name
if [ $c_re -eq 6 ]; then
    chkconfig iptables off
    if [ ! -z $h_name ]; then
        hostname $h_name
        cat > /etc/sysconfig/network << EOF
HOSTNAME=$h_name
EOF
    fi
elif [ $c_re -eq 7 ]; then
    systemctl disable firewalld
    cd /etc/sysconfig/network-scripts/
    rm -f `ls | grep "ens"`
    grep -q "biosdevname" /etc/default/grub
    if [ $? -ne 0 ]; then
        sed -i.bak '/CMDLINE/s/t"$/t net.ifnames=0 biosdevname=0"/'  /etc/default/grub
        grub2-mkconfig -o /boot/grub2/grub.cfg
    fi
    if [ ! -z $h_name ]; then
        hostname $h_name
        hostnamectl set-hostname $h_name
    fi
fi

cat > ~/.vimrc <<EOF
set fileencodings=utf-8,ucs-bom,gb18030,gbk,gb2312,cp936
set termencoding=utf-8
set encoding=utf-8
set autoindent    " 打开自动缩进
set smartindent   " 打开智能缩进
set smarttab 
set incsearch     " 开启实时搜索功能（字串随你每输入一个字符不断更新）
set ignorecase    " 搜索时大小写不敏感,搜索小写可以匹配大写
set smartcase     " 搜索大写只匹配大写
set wildmenu      " vim 自身命令行模式智能补全
syntax on         " 语法高亮
set expandtab     " Tab 转换为空格
set tabstop=4     " Tab 转换为 4 个字符位
set softtabstop=4
set shiftwidth=4
set nu
EOF
#提示符颜色
cat >> /etc/profile <<'EOF'
export PS1='\[\e[34;1m\][\u@\h \W]\$ \[\e[0m\]'
EOF
choose="Yes no"
echo "是否现在重启服务器，请输入编号。"
select ch in $choose
do
    if [ "${ch}" = "Yes" ]; then
        echo "系统将在3秒后重启，Ctrl+C 取消"
        echo "3"
        sleep 1
        echo "2"
        sleep 1
        echo "1"
        sleep 1
        history -c
        clear
        reboot
    elif [ "${ch}" = "no" ];then
        echo "必须重启系统使配置生效"
    fi
done