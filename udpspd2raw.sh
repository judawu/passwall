#!/bin/bash

cat >&1 <<-'EOF'
#########################################################
# 一键安装，卸载，管理Updspeed/Udp2raw脚本
    感谢wangyu大佬https://github.com/wangyu-/
    感谢其他网络大佬,脚本很多地方是抄的
	该脚本是本人修改的自用脚本，供学习用，不传播。
	如果侵权了，请联系本人删除
	judawu@gamil.com
#
#########################################################
EOF

# 默认参数
# =======================
D_LISTEN_PORT=9999
D_TARGET_ADDR='127.0.0.1'
D_TARGET_PORT=8888
D_KEY=”password“
D_FEC_X=10
D_FEC_Y=20
D_TIMEOUT=0
D_MTU=1350


# ======================


clear

red='\e[91m'
green='\e[92m'
yellow='\e[93m'
none='\e[0m'

[[ $(id -u) != 0 ]] && echo -e " \n请使用 ${red}root ${none}用户运行 ${yellow}~(^_^) ${none}\n" && exit 1

cmd="apt-get"

sys_bit=$(uname -m)

# 检测方法
if [[ -f /usr/bin/apt-get ]] || [[ -f /usr/bin/yum ]]; then

	if [[ -f /usr/bin/yum ]]; then

		cmd="yum"

	fi

else

	echo -e " \n这个 ${red}脚本${none} 不支持你的系统。 ${yellow}(-_-) ${none}\n" && exit 1

fi

if [[ $sys_bit == "i386" || $sys_bit == "i686" ]]; then
	speeder_ver="speederv2_x86"
	udp2raw_ver="udp2raw_x86"
elif [[ $sys_bit == "x86_64" ]]; then
	speeder_ver="speederv2_amd64"
	udp2raw_ver="udp2raw_amd64"
else
	echo -e " \n$red不支持你的系统....$none\n" && exit 1
fi

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


# 按任意键继续
any_key_to_continue() {
	echo "请按任意键继续或 Ctrl + C 退出"
	local saved=""
	saved="$(stty -g)"
	stty -echo
	stty cbreak
	dd if=/dev/tty bs=1 count=1 2>/dev/null
	stty -raw
	stty echo
	stty $saved
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

install_udpspeeder() {
	$cmd install wget -y
 	ver=$(curl -s https://api.github.com/repos/wangyu-/UDPspeeder/releases/latest grep ‘tag_name’| cut -d\" -f4)
   
	UDPspeeder_download_link="https://github.com/wangyu-/UDPspeeder/releases/download/$ver/speederv2_binaries.tar.gz"
	
	mkdir -p /tmp/UDPspeeder

	if ! wget --no-check-certificate --no-cache -O "/tmp/UDPspeeder.tar.gz" $UDPspeeder_download_link; then
		echo -e "$red 下载 UDPspeeder 失败！$none" && exit 1
	fi
	tar zxf /tmp/UDPspeeder.tar.gz -C /tmp/UDPspeeder
	cp -f /tmp/UDPspeeder/$speeder_ver /usr/bin/speederv2
	chmod +x /usr/bin/speederv2
	if [[ -f /usr/bin/speederv2 ]]; then
		clear
		echo -e " 
		$green UDPspeeder 安装完成...$none	
		"
	else
		echo -e " \n$red安装失败...$none\n"
	fi
	rm -rf /tmp/UDPspeeder
	rm -rf /tmp/UDPspeeder.tar.gz
	
	while true
	do
		echo -e "\n$red是否开启UDPspeeder...$none\n"
		
		read -p "(请输入 [y/n]: " yn
		if [ -n "$yn" ]; then
			case "$(first_character "$yn")" in
				y|Y)
					start_udpspeeder
					;;
				n|N)
				echo "\n$green你选择了不启动，请手动启动吧，或者把脚本再运行一遍选择启动!$none\n"
					any_key_to_continue
					;;
				*)
					echo "\n$red输入有误，请重新输入!$none\n"
					continue
					;;
			esac
		fi
		break
	done
}

uninstall__udpspeeder() {
	if [[ -f /usr/bin/speederv2 ]]; then
		UDPspeeder_pid=$(pgrep "speederv2")
		[ $UDPspeeder_pid ] && kill -9 $UDPspeeder_pid
		rm -rf /usr/bin/speederv2
		echo -e " \n$green卸载完成...$none\n" && exit 1
	else
		echo -e " \n$red你没有安装 UDPspeeder ....不能卸载哦...$none\n" && exit 1
	fi
}


start_udpspeeder() {

	local input=""
	local yn=""

	# 设置服务运行端口
	[ -z "$listen_port" ] && listen_port="$D_LISTEN_PORT"
	while true
	do
		echo -e " \n$green请输入监听端口，监听端口是Server和Client通讯的端口...$none\n"
		read -p "(默认: ${listen_port}): " input
		if [ -n "$input" ]; then
			if is_port "$input"; then
				listen_port="$input"
			else
				echo "输入有误, 请输入 1~65535 之间的数字!"
				continue
			fi
		fi

		if port_using "$listen_port" && \
			[ "$listen_port" != "$current_listen_port" ]; then
			echo "端口已被占用, 请重新输入!"
			continue
		fi
		break
	done

	input=""

   
	[ -z "$target_addr" ] && target_addr="$D_TARGET_ADDR"
	
    echo -e " \n$green请输入目标IP...$none\n"
	read -p "(默认: ${target_addr}): " input
	if [ -n "$input" ]; then
		target_addr="$input"
	fi

	input=""
	
	[ -z "$target_port" ] && target_port="$D_TARGET_PORT"
	while true
	do
	  echo -e " \n$green请输入目标端口，目标端口是你转发的SSR/V2RAY/OPNVPN应用的端口...$none\n"
		read -p "(默认: ${target_port}): " input
		if [ -n "$input" ]; then
			if is_port "$input"; then
				if [ "$input" = "$listen_port" ]; then
					echo "运行端口不能和监听端口一致!"
					continue
				fi

				target_port="$input"
			else
				echo "输入有误, 请输入 1~65535 之间的数字!"
				continue
			fi
		fi

		if [ "$target_addr" = "127.0.0.1" ] && ! port_using "$target_port"; then
			read -p "当前没有软件使用此端口, 确定使用此端口? [y/n]: " yn
			if [ -n "$yn" ]; then
				case "$(first_character "$yn")" in
					y|Y)
						;;
					*)
						continue
						;;
				esac
			fi
		fi

		break
	done

	input=""
	yn=""


	[ -z "$key" ] && key="$D_KEY"
	echo "输入有误, 请输入通讯密码!"
	read -p "(默认密码: ${key}): " input
	[ -n "$input" ] && key="$input"

	input=""
	

	[ -z "$mtu" ] && mtu="$D_MTU"
	while true
	do
		echo "请输入MTU Pakcage的值!"
		read -p "(默认: ${mtu}): " input
		if [ -n "$input" ]; then
			if ! is_number "$input" || [ $input -le 0 ]; then
				echo "输入有误, 请输入大于0的数字!"
				continue
			fi

			mtu=$input
		fi
		break
	done
	input=""

    
	[ -z "$fec_x" ] && mtu="$D_FEC_X"
	while true
	do
		echo "请输入FEC_X的值!"
		read -p "(默认: ${fec_x}): " input
		if [ -n "$input" ]; then
			if ! is_number "$input" || [ $input -le 0 ]; then
				echo "输入有误, 请输入大于0的数字!"
				continue
			fi

			fec_x=$input
		fi
		break
	done
	input=""

    [ -z "$fec_y" ] && mtu="$D_FEC_Y"
	while true
	do
		echo "请输入FEC_X的值!"
		read -p "(默认: ${fec_y}): " input
		if [ -n "$input" ]; then
			if ! is_number "$input" || [ $input -le 0 ]; then
				echo "输入有误, 请输入大于0的数字!"
				continue
			fi

			fec_x=$input
		fi
		break
	done
	input=""
	
	
	# 判断书服务端还是客户端，启动相应的代码
	
		echo -e " \n$green请输入监听端口，监听端口是Server和Client通讯的端口...$none\n"
		read -p "(默认是服务端: [y/n]): " input
		if [ -n "$yn" ]; then
				case "$(first_character "$yn")" in
					y|Y)
						
                # Run at server side:
                ./speederv2 -s -l0.0.0.0:$listen_port -r $target_addr:$target_port  -f $fec_x:$fec_y -k $key
				        ;;
					*)
				./speederv2 -c -l0.0.0.0:$target_port  -r $target_addr:$listen_port -f $fec_x:$fec_y0 -k $key
						;;
				esac
		fi
		


}

stop_udpspeeder() {

kill  ./speederv2 

}
help_udpspeeder() {

  echo -e ”请访问  https://github.com/wangyu-/UDPspeeder/wiki 获得帮助“
  	cat >&1 <<-'EOF'
	
	建议新手用--mode 0模式，可以避免MTU问题。
    在mode 0模式下，-f x:y参数里的x需要>=2
	-f20:10 --timeout 8是默认参数，可以不写出来
	如果你的网络丢包率非常高，可以把-f20:10改为-f20:20，这样消耗的是两倍流量
    如果你想节省CPU, 可以把-f20:10改为-f10:5
    游戏模式，3倍流量，-f2:4 --timeout 1
	注1：--timeout 0只能配合-f2:x使用, 不当使用此参数可能会极大地浪费带宽
    游戏模式 1.6倍的流量	-f10:6 --timeout 3
	--timeout t的值决定允许的最大延迟
	-i参数 -i 10 用交错FEC的方式，牺牲一定的延迟10ms，来抵御网络的突发性丢包
	
	
	帮助不够看
	哎呀，我也不懂啊，看上面的链接把
		EOF

}



install_upd2raw() {
	$cmd install wget -y
	ver=$(curl -s https://api.github.com/repos/wangyu-/udp2raw-tunnel/releases/latest | grep 'tag_name' | cut -d\" -f4)
	
	upd2raw_download_link="https://github.com/wangyu-/udp2raw-tunnel/releases/download/$ver/udp2raw_binaries.tar.gz"
	                    
	mkdir -p /tmp/Udp2raw
	if ! wget --no-check-certificate -O "/tmp/udp2raw_binaries.tar.gz" $udp2raw_download_link; then
		echo -e "$red 下载 Udp2raw-tunnel 失败！$none" && exit 1
	fi
	tar zxf /tmp/udp2raw_binaries.tar.gz -C /tmp/Udp2raw
	cp -f /tmp/Udp2raw/$udp2raw_ver /usr/bin/udp2raw
	chmod +x /usr/bin/udp2raw
	if [[ -f /usr/bin/udp2raw ]]; then
		clear
		echo -e " 
		$green Udp2raw-tunnel 安装完成...$none	
		"
	else
		echo -e " \n$red安装失败...$none\n"
	fi
	rm -rf /tmp/Udp2raw
	rm -rf /tmp/udp2raw_binaries.tar.gz
		while true
	do
		echo -e "\n$red是否开启UDPspeeder...$none\n"
		
		read -p "(请输入 [y/n]: " yn
		if [ -n "$yn" ]; then
			case "$(first_character "$yn")" in
				y|Y)
					start_udp2raw
					;;
				n|N)
				echo "\n$green你选择了不启动，请手动启动吧，或者把脚本再运行一遍选择启动!$none\n"
					any_key_to_continue
					;;
				*)
					echo "\n$red输入有误，请重新输入!$none\n"
					continue
					;;
			esac
		fi
		break
	done
}
uninstall_upd2raw() {
	if [[ -f /usr/bin/udp2raw ]]; then
		udp2raw_pid=$(pgrep "udp2raw")
		[ $udp2raw_pid ] && kill -9 $udp2raw_pid
		rm -rf /usr/bin/udp2raw
		echo -e " \n$green卸载完成...$none\n" && exit 1
	else
		echo -e " \n$red...你没有有安装 Udp2raw-tunnel ....不能再卸载了...$none\n" && exit 1
	fi
}

start_udp2raw() {



	local input=""
	local yn=""

	# 设置服务运行端口
	[ -z "$listen_port" ] && listen_port="$D_LISTEN_PORT"
	while true
	do
		echo -e " \n$green请输入监听端口，监听端口是Server和Client通讯的端口...$none\n"
		read -p "(默认: ${listen_port}): " input
		if [ -n "$input" ]; then
			if is_port "$input"; then
				listen_port="$input"
			else
				echo "输入有误, 请输入 1~65535 之间的数字!"
				continue
			fi
		fi

		if port_using "$listen_port" && \
			[ "$listen_port" != "$current_listen_port" ]; then
			echo "端口已被占用, 请重新输入!"
			continue
		fi
		break
	done

	input=""

   
	[ -z "$target_addr" ] && target_addr="$D_TARGET_ADDR"
	
    echo -e " \n$green请输入目标IP...$none\n"
	read -p "(默认: ${target_addr}): " input
	if [ -n "$input" ]; then
		target_addr="$input"
	fi

	input=""
	
	[ -z "$target_port" ] && target_port="$D_TARGET_PORT"
	while true
	do
	  echo -e " \n$green请输入目标端口，目标端口是你转发的SSR/V2RAY/OPNVPN应用的端口...$none\n"
		read -p "(默认: ${target_port}): " input
		if [ -n "$input" ]; then
			if is_port "$input"; then
				if [ "$input" = "$listen_port" ]; then
					echo "运行端口不能和监听端口一致!"
					continue
				fi

				target_port="$input"
			else
				echo "输入有误, 请输入 1~65535 之间的数字!"
				continue
			fi
		fi

		if [ "$target_addr" = "127.0.0.1" ] && ! port_using "$target_port"; then
			read -p "当前没有软件使用此端口, 确定使用此端口? [y/n]: " yn
			if [ -n "$yn" ]; then
				case "$(first_character "$yn")" in
					y|Y)
						;;
					*)
						continue
						;;
				esac
			fi
		fi

		break
	done

	input=""
	yn=""


	[ -z "$key" ] && key="$D_KEY"
	echo "输入有误, 请输入通讯密码!"
	read -p "(默认密码: ${key}): " input
	[ -n "$input" ] && key="$input"

	input=""
	



  
	
	
	# 判断书服务端还是客户端，启动相应的代码
	
		echo -e " \n$green请输入监听端口，监听端口是Server和Client通讯的端口...$none\n"
		read -p "(默认是服务端: [y/n]): " input
		if [ -n "$yn" ]; then
				case "$(first_character "$yn")" in
					y|Y)
						
                # Run at server side:
                ./udp2raw_amd64 -s -l0.0.0.0:$listen_port -r $target_addr:$target_port  -k $key --raw-mode faketcp -a
				        ;;
					*)
				./udp2raw_amd64 -c -l0.0.0.0:$target_port  -r $target_addr:$listen_port  -k $key --raw-mode faketcp -a
						;;
				esac
		fi
		


}

stop_udp2raw() {

kill  ./udp2raw_amd64 

}
help_udp2raw() {

  echo -e ”请访问  https://github.com/wangyu-/udp2raw-tunnel/wiki 获得帮助“
  	cat >&1 <<-'EOF'
	使用-a选项自动添加、或-g选项手动添加所需的iptables规则
	
	帮助不够看
	哎呀，我也不懂啊，看上面的链接把
	EOF

}


error() {

	echo -e "\n$red 输入错误！$none\n"
	any_key_to_continue

}
while :; do
	echo
	echo "........... UDPspeeder/Upd2Raw快速一键安装........."
	echo
	echo " 1. 安装udpspeed"
	echo " 2. 卸载udpspeed"
	echo " 3. 安装udp2raw"
	echo " 4. 卸载udp2raw"
	echo " 5. 启动udpspeed"
	echo " 6. 停止udpspeed"
	echo " 7. 启动udp2raw"
	echo " 8. 停止udp2raw"
	echo " 9. 查看帮助udpSpeed"
	echo " 10. 查看帮助udp2raw"
	
	echo
	read -p "请选择[1-4]:" choose
	case $choose in
	1)
		install_udpspeeder
		break
		;;
	2)
		uninstall_udpspeeder
		break
		;;
	3)
		install_upd2raw
		break
		;;
	4)
		uninstall_upd2raw
		break
		;;	
	5)
		start_udpspeeder
		break
		;;
	6)
		stop_udpspeeder
		break
		;;
	7)
		help_udpspeeder
		break
		;;
	8)
		start_upd2raw
		break
		;;	
	9)
		stop_udp2raw
		break
		;;
	10)
		help_upd2raw
		break
		;;			
	*)
		error
		;;
	esac
	
done