clear

red='\e[91m'
green='\e[92m'
yellow='\e[93m'
none='\e[0m'



# 按任意键继续
any_key_to_continue() {
	echo -e "\n$red请按任意键继续或 Ctrl + C 退出${none}\n"
	local saved=""
	saved="$(stty -g)"
	stty -echo
	stty cbreak
	dd if=/dev/tty bs=1 count=1 2>/dev/null
	stty -raw
	stty echo
	stty $saved
}
error() {

	echo -e "\n$red 输入错误！$none\n"
	any_key_to_continue

}

# 判断命令是否存在
command_exists() {
	command -v "$@" >/dev/null 2>&1
}

# 判断输入内容是否为数字
is_number() {
	expr "$1" + 1 >/dev/null 2>&1
}

first_character() {
	if [ -n "$1" ]; then
		echo "$1" | cut -c1
	fi
}

#检查是否具有 root 权限
check_root() {
	local user=""
	
	user="$(id -un 2>/dev/null || true)"
	if [ "$user" != "root" ]; then
		echo  "${red}\n权限错误, 请使用 root 用户运行此脚本!${none}\n"
	
		exit 1
	fi
	
	  echo  "$green当前用户是root 用户权限"
	
}

get_os_info() {
	lsb_dist=""
	dist_version=""
	if command_exists lsb_release; then
		lsb_dist="$(lsb_release -si)"
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/lsb-release ]; then
		lsb_dist="$(. /etc/lsb-release && echo "$DISTRIB_ID")"
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/debian_version ]; then
		lsb_dist='debian'
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/fedora-release ]; then
		lsb_dist='fedora'
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/oracle-release ]; then
		lsb_dist='oracleserver'
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/centos-release ]; then
		lsb_dist='centos'
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/redhat-release ]; then
		lsb_dist='redhat'
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/photon-release ]; then
		lsb_dist='photon'
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/os-release ]; then
		lsb_dist="$(. /etc/os-release && echo "$ID")"
	fi

	lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"

	if [ "${lsb_dist}" = "redhatenterpriseserver" ]; then
		lsb_dist='redhat'
	fi

	case "$lsb_dist" in
		ubuntu)
			if command_exists lsb_release; then
				dist_version="$(lsb_release --codename | cut -f2)"
			fi
			if [ -z "$dist_version" ] && [ -r /etc/lsb-release ]; then
				dist_version="$(. /etc/lsb-release && echo "$DISTRIB_CODENAME")"
			fi
			;;

		debian|raspbian)
			dist_version="$(cat /etc/debian_version | sed 's/\/.*//' | sed 's/\..*//')"
			case "$dist_version" in
				9)
					dist_version="stretch"
					;;
				8)
					dist_version="jessie"
					;;
				7)
					dist_version="wheezy"
					;;
			esac
			;;

		oracleserver)
			lsb_dist="oraclelinux"
			dist_version="$(rpm -q --whatprovides redhat-release --queryformat "%{VERSION}\n" | sed 's/\/.*//' | sed 's/\..*//' | sed 's/Server*//')"
			;;

		fedora|centos|redhat)
			dist_version="$(rpm -q --whatprovides ${lsb_dist}-release --queryformat "%{VERSION}\n" | sed 's/\/.*//' | sed 's/\..*//' | sed 's/Server*//' | sort | tail -1)"
			;;

		"vmware photon")
			lsb_dist="photon"
			dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
			;;

		*)
			if command_exists lsb_release; then
				dist_version="$(lsb_release --codename | cut -f2)"
			fi
			if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
				dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
			fi
			;;
	esac

	if [ -z "$lsb_dist" ] || [ -z "$dist_version" ]; then
        echo "$red不能获取系统信息"
		exit 1
	fi
	#echo "$lsb_dist"，"$dist_version"
	 
}
# 获取服务器架构和 passwall 服务端文件后缀名
get_arch() {
	architecture="$(uname -m)"
	case "$architecture" in
		amd64|x86_64)
			spruce_type='linux-amd64'
			file_suffix='linux_amd64'
			;;
		i386|i486|i586|i686|x86)
			spruce_type='linux-386'
			file_suffix='linux_386'
			;;
		*)
			
		echo "$red当前脚本仅支持 32 位 和 64 位系统,你的系统为: $architecture"
		
			exit 1
			;;
	esac
	echo "$architecture"
}

# 获取服务器的IP地址
get_server_ip() {
	local server_ip=""
	local interface_info=""
    if command_exists ip; then
		interface_info="$(ip addr)"
	elif command_exists ifconfig; then
		interface_info="$(ifconfig)"
	fi

	server_ip=$(echo "$interface_info" | \
		grep -oE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | \
		grep -vE "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | \
		head -n 1)

	# 自动获取失败时，通过网站提供的 API 获取外网地址
	if [ -z "$server_ip" ]; then
		 server_ip="$(wget -qO- --no-check-certificate https://ipv4.icanhazip.com)"
	fi

	echo "$server_ip"
}
	is_port() {
		local port="$1"
		is_number "$port" && \
			[ $port -ge 1 ] && [ $port -le 65535 ]
	}

	port_using() {
		local port="$1"

		if command_exists netstat; then
			( netstat -ntul | grep -qE "[0-9:*]:${port}\s" )
		elif command_exists ss; then
			( ss -ntul | grep -qE "[0-9:*]:${port}\s" )
		else
			return 0
		fi

		return $?
	}


# 禁用 selinux
disable_selinux() {
	local selinux_config='/etc/selinux/config'
	if [ -s "$selinux_config" ]; then
		if grep -q "SELINUX=enforcing" "$selinux_config"; then
			sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' "$selinux_config"
			setenforce 0
		fi
	fi
}

# 检测系统




check_sys() {
[[ $(id -u) != 0 ]] && echo -e " \n请使用 ${red}root ${none}用户运行 ${yellow}~(^_^) ${none}\n" && exit 1



if [[ -f /usr/bin/apt-get ]] || [[ -f /usr/bin/yum ]]; then
	if [[ -f /usr/bin/yum ]]; then
		cmd="yum"
	fi
	if [[ -f /usr/bin/apt-get ]]; then
		cmd="apt-get"
	fi
else
	echo -e " \n这个 ${red}脚本${none} 不支持你的系统。 ${yellow}(-_-) ${none}\n" && exit 1
fi
get_os_info
get_server_ip
get_arch
}
 v2ray_go(){

 date -R
 cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
 bash <(curl -L -s https://install.direct/go.sh)

while true
	do	echo -e "\n$green v2ray已经安装和配置，是否用网站的json文件来替换默认json？...$none\n"
		read -p "(请输入 [y/n]): " yn
		if [ -n "$yn" ]; then
			case "$(first_character "$yn")" in
				y|Y)
                  mv /etc/v2ray/config.json  /etc/v2ray/config.json.bk
                  if ! wget --no-check-certificate --no-cache -O "/etc/v2ray/config.json" https://raw.githubusercontent.com/judawu/passwall/master/v2ray_server.json; then
                     mv /etc/v2ray/config.json  /etc/v2ray/config.json.bk
		             echo -e "$red 下载config.json 失败$none" 
	              fi
 	;;			;;	
				*)					
					break
					;;
			esac
		fi
	break
done

while true
	do  echo -e "\n$green 是否安装证书ACME...$none\n"		  
		read -p "(请输入 [y/n]): " yn
		if [ -n "$yn" ]; then
			case "$(first_character "$yn")" in
				y|Y)
					acme_go
					;;				
				*)					
					break
					;;
			esac
		fi
	break
done

while true
	do  echo -e "\n$green 是否安装Ngnix（如果已经安装Caddy或Ngnix），请忽略...$none\n"		 
		read -p "(请输入 [y/n]): " yn
		if [ -n "$yn" ]; then
			case "$(first_character "$yn")" in
				y|Y)
					ngnix_go
					;;				
				*)					
					break
					;;
			esac
		fi
	break
done

while true
	do  echo -e "\n$green 配置结束了，重启V2ray吧...$none\n"		 
		read -p "(请输入 [y/n]): " yn
		if [ -n "$yn" ]; then
			case "$(first_character "$yn")" in
				y|Y)
					service v2ray restart 
					;;				
				*)					
					break
					;;
			esac
		fi
	break
done

 }
 
acme_go(){

 if  [[ -f /usr/bin/socat ]] then
   echo -e "\n$green 已安装依赖socat/netcat...$none\n"   
 else
    if [[ -f /usr/bin/yum ]]; then
		sudo yum -y install socat
		#sudo yum -y install netcat
	fi
    if [[ -f /usr/bin/apt-get ]]; then
		sudo apt-get -y install socat
		#sudo apt-get -y install netcat
    fi
 fi
while true 
  do  
        echo -e "\n$green 请输入你的Domian名，此Domain用于配置TLS，可能不会配置成功...$none\n"		 
		read -p "(请输入): " server_domain
		if [ -n "$yn" ]; then
			break
		else
		    continue
		fi
  break
done


while true
	do  
	    echo -e "\n$green请选择是更新证书还是安装证书...$none\n"
        echo " 1. 安装证书"
	    echo " 2. 更新证书"
	    echo
        read -p "请选择[1-2]:" chose
	    case $chose in
	      1)
             curl  https://get.acme.sh | sh
		     sudo ~/.acme.sh/acme.sh --issue -d $server_domain --standalone -k ec-256
			 sudo ~/.acme.sh/acme.sh --installcert -d $server_domain --fullchainpath /etc/v2ray/v2ray.crt --keypath /etc/v2ray/v2ray.key --ecc
		     break
		     ;;
	      2)
		     sudo ~/.acme.sh/acme.sh --renew -d $server_domain  --force --ecc
		     break
		     ;;	
	      *)
		     break
		     ;;
	   esac
done

}


ssr_go() {
 echo -e "\n$green 不好意思，SSR我还没有写部署步骤...$none\n"
}
trojan_go() {
 echo -e "\n$green 不好意思，TROJAN我还没有写部署步骤...$none\n"
}
ngnix_go() {

if  [[ -f /etc/nginx/sites-available ]]; then
    echo -e "\n$green nginx已经安装和配置过了"
else
  if [[ -f /usr/bin/yum ]]; then
		sudo yum -y install nginx
		
  fi
  if [[ -f /usr/bin/apt-get ]]; then
		sudo apt-get -y install nginx
  fi
fi
while true
	do	
	    echo -e "\n$green nginx已经安装和配置，是否用网站的配置文件来替换默认配置？...$none\n"
		read -p "(请输入 [y/n]): " yn
		if [ -n "$yn" ]; then
			case "$(first_character "$yn")" in
				y|Y)
                  mv /etc/nginx/sites-available/default   /etc/nginx/sites-available/default.bk 
                  if ! wget --no-check-certificate --no-cache -O "/etc/nginx/sites-available/default" https://raw.githubusercontent.com/judawu/passwall/master/nginx_default; then
                     mv /etc/nginx/sites-available/default.bk  /etc/nginx/sites-available/default
		             echo -e "$red 下载Nginx default 失败$none" 
	              fi
 				   ;;	
				*)					
					break
					;;
			esac
		fi
	break
done
}
caddy_go() {
   echo -e "\n$green 不好意思，Caddy我还没有写部署步骤...$none\n"
}
appache_go() {
  echo -e "\n$green 不好意思，appache我还没有写部署步骤...$none\n"

#查看apache2安装包信息，appache2放在/etc/apache2/，用conf-available查看可用conf，用config-enabled这一对命令来启用conf
#apt-cache show apache2
#探测一下
#namp 127.0.0.1
#安装apache2
#sudo apt-get intall apache2
#namp 127.0.0.1
#cd /etc/apache2
#启用appache2模块ssl
#sudo a2enmod ssl
#关闭appache2模块ssl
#sudo a2dismod ssl

#配置appache建立网站，先查看网站哪些启动了#
#ll site-available
#ll site-enabled
#启用appache2网站
#sudo a2ensite 000-default
#配置网站信息
#sudo nano  site-available/mysite。conf

#sudo mkdir -p /var/www/mysite
#sudo chown user:password +R  /var/www/mysite/
#cd  /var/www/mysite
#nano index.html

#sudo a2ensite mysite
#重启appache2
#sudo service appche2 restart

}
website_go() {
      echo -e "\n$green 不好意思，website我还没有写部署步骤...$none\n"
	  #sudo apt-get install dnsutils -y
       #dig www.google.com @127.0.0.1 -p 53
}
bbr_go() {

if $lsb_dist=="debian"; then
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
fi

}
udpspd2raw_go() {

wget --no-check-certificate --no-cache -O "/etc/v2ray/config.json" https://raw.githubusercontent.com/judawu/passwall/master/udpspd2raw.sh && chmod +x ./udpspd2raw.sh  && ./udpspd2raw.sh
}

kcprun_go() {

    echo -e "\n$green 不好意思，kcprun我还没有写部署步骤...$none\n"
}




check_sys

	

while :; do
	echo
	echo "........... V2ray/SSR/Trojan快速部署........"
	echo
	echo " 1. 安装和部署V2ray"
	echo " 2. 安装和部署SSR"
	echo " 3. 安装和部署Trojan"
	echo " 4. 安装和部署Ngnix"
	echo " 5. 安装和部署Caddy"
	echo " 6. 安装和部署acme TLS证书"
	echo " 7. 安装和部署appache"
	echo " 8. 安装和部署bbr"
	echo " 9. 安装和部署伪装网站,探测工具等"
	echo " 10. 安装和部署udpspeed，upd2raw"
	echo " 11. 安装和部署kcprun"
	
	echo
	read -p "请选择[1-10]:" choose
	case $choose in
	1)
        v2ray_go
		break
		;;
	2)
		ssr_go
		break
		;;
	3)
		trojan_go
		break
		;;
	4)
		ngnix_go
		break
		;;	
	5)
		caddy_go
		9break
		;;
	6)
		acme_go
		break
		;;
	7)
		appache_go
		break
		;;
	8)
		bbr_go
		break
		;;	
	9)
		website_go
		break
		;;
	10)
		udpspd2raw_go
		break
		;;			
	11)
		kcprun_go
		;;
	*)
		any_key_to_continue
		;;
	esac
	
done


