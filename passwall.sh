#!/bin/sh

: <<-'EOF'
Copyright 2020 <JudaWu@gmail.com>
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
	http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
EOF

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# 版本信息，请勿修改
# =================
SHELL_VERSION=1
CONFIG_VERSION=0
INIT_VERSION=0
# =================

INSTALL_DIR='/usr/local/passwall'
OG_DIR='/var/log/passwall'
RELEASES_URL='https://api.github.com/judawu/passwall/releases'
LATEST_RELEASE_URL="${RELEASES_URL}/latest"
TAGS_URL='https://github.com/judawu/passwall/tags'

BASE_URL='https://github.com/udawu/passwall/releases/base'
SHELL_VERSION_INFO_URL="${BASE_URL}/version.json"

JQ_DOWNLOAD_URL="https://github.com/stedolan/jq/releases/download/jq-1.5/"
JQ_LINUX32_URL="${JQ_DOWNLOAD_URL}/jq-linux32"
JQ_LINUX64_URL="${JQ_DOWNLOAD_URL}/jq-linux64"
JQ_LINUX32_HASH='ab440affb9e3f546cf0d794c0058543eeac920b0cd5dff660a2948b970beb632'
JQ_LINUX64_HASH='c6b3a7d7d3e7b70c6f51b706a3b90bd01833846c54d32ca32f0027f00226ff6d'
JQ_BIN="${INSTALL_DIR}/bin/jq"

SUPERVISOR_SERVICE_FILE_DEBIAN_URL="${BASE_URL}/startup/supervisord.init.debain"
SUPERVISOR_SERVICE_FILE_REDHAT_URL="${BASE_URL}/startup/supervisord.init.redhat"
SUPERVISOR_SYSTEMD_FILE_URL="${BASE_URL}/startup/supervisord.systemd"

# 默认参数
# =======================

# ======================

# 当前选择的实例 ID
current_instance_id=""
run_user='passwall'

clear

cat >&1 <<-'EOF'
#########################################################
# Passwall服务端一键安装脚本                             #
# 该脚本支持 Passwall 服务端的安装、更新、卸载及配置       #
# 脚本作者: Index <Juda@gmail.com>                      #
# Github: https://github.com/judawu/passwall           #
#########################################################
EOF

# 打印帮助信息
usage() {
	cat >&1 <<-EOF
	请使用: $0 <option>
	可使用的参数 <option> 包括:
	    install          安装
	    uninstall        卸载
	    update           检查更新
	    manual           自定义 passwall 版本安装
	    help             查看脚本使用说明
	    add              添加一个实例, 多端口加速
	    reconfig <id>    重新配置实例
	    show <id>        显示实例详细配置
	    log <id>         显示实例日志
	    del <id>         删除一个实例
	注: 上述参数中的 <id> 可选, 代表的是实例的ID
	    可使用 1, 2, 3 ... 分别对应子实例 ，目前不可用
	    若不指定 <id>, 则默认为 1
	Supervisor 命令:
	    service supervisord {start|stop|restart|status}
	                        {启动|关闭|重启|查看状态}
	Kcptun 相关命令:
	    supervisorctl {start|stop|restart|status} passwall<id>
	                  {启动|关闭|重启|查看状态}
	EOF

	exit $1
}

# 判断命令是否存在
command_exists() {
	command -v "$@" >/dev/null 2>&1
}

# 判断输入内容是否为数字
is_number() {
	expr "$1" + 1 >/dev/null 2>&1
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

first_character() {
	if [ -n "$1" ]; then
		echo "$1" | cut -c1
	fi
}
#!/bin/sh

: <<-'EOF'
Copyright 2020 
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
	http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
EOF

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# 版本信息，请勿修改
# =================
SHELL_VERSION=1
CONFIG_VERSION=0
INIT_VERSION=0
# =================

cat >&1 <<-'EOF'
#########################################################
# 系统检测脚本                             #
#########################################################
EOF


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


#检查是否具有 root 权限
check_root() {
	local user=""
	user="$(id -un 2>/dev/null || true)"
	if [ "$user" != "root" ]; then
		cat >&2 <<-'EOF'
		权限错误, 请使用 root 用户运行此脚本!
		EOF
		exit 1
	fi
	cat >&2 <<-'EOF'
	    root 用户权限
		EOF
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

# 获取当前操作系统信息
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
		cat >&2 <<-EOF
		无法确定服务器系统版本信息。
		请联系脚本作者。
		EOF
		exit 1
	fi
	echo "$lsb_dist"，"$dist_version"
	 
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
			cat 1>&2 <<-EOF
			当前脚本仅支持 32 位 和 64 位系统
			你的系统为: $architecture
			EOF
			exit 1
			;;
	esac
	echo "$architecture"
}
# 下载文件， 默认重试 3 次
download_file() {
	local url="$1"
	local file="$2"
	local verify="$3"
	local retry=0
	local verify_cmd=""

	verify_file() {
		if [ -z "$verify_cmd" ] && [ -n "$verify" ]; then
			if [ "${#verify}" = "32" ]; then
				verify_cmd="md5sum"
			elif [ "${#verify}" = "40" ]; then
				verify_cmd="sha1sum"
			elif [ "${#verify}" = "64" ]; then
				verify_cmd="sha256sum"
			elif [ "${#verify}" = "128" ]; then
				verify_cmd="sha512sum"
			fi

			if [ -n "$verify_cmd" ] && ! command_exists "$verify_cmd"; then
				verify_cmd=""
			fi
		fi

		if [ -s "$file" ] && [ -n "$verify_cmd" ]; then
			(
				set -x
				echo "${verify}  ${file}" | $verify_cmd -c
			)
			return $?
		fi

		return 1
	}

	download_file_to_path() {
		if verify_file; then
			return 0
		fi

		if [ $retry -ge 3 ]; then
			rm -f "$file"
			cat >&2 <<-EOF
			文件下载或校验失败! 请重试。
			URL: ${url}
			EOF

			if [ -n "$verify_cmd" ]; then
				cat >&2 <<-EOF
				如果下载多次失败，你可以手动下载文件:
				1. 下载文件 ${url}
				2. 将文件重命名为 $(basename "$file")
				3. 上传文件至目录 $(dirname "$file")
				4. 重新运行安装脚本
				注: 文件目录 . 表示当前目录，.. 表示当前目录的上级目录
				EOF
			fi
			exit 1
		fi

		( set -x; wget -O "$file" --no-check-certificate "$url" )
		if [ "$?" != "0" ] || [ -n "$verify_cmd" ] && ! verify_file; then
			retry=$(expr $retry + 1)
			download_file_to_path
		fi
	}

	download_file_to_path
}

# 安装 jq 用于解析和生成 json 文件
# jq 已进入大部分 Linux 发行版的软件仓库，
#  	URL: https://stedolan.github.io/jq/download/
# 但为了防止有些系统安装失败，还是通过脚本来提供了。
install_jq() {
	check_jq() {
		if [ ! -f "$JQ_BIN" ]; then
			return 1
		fi

		[ ! -x "$JQ_BIN" ] && chmod a+x "$JQ_BIN"

		if ( $JQ_BIN --help 2>/dev/null | grep -q "JSON" ); then
			is_checked_jq="true"
			return 0
		else
			rm -f "$JQ_BIN"
			return 1
		fi
	}

	if [ -z "$is_checked_jq" ] && ! check_jq; then
		local dir=""
		dir="$(dirname "$JQ_BIN")"
		if [ ! -d "$dir" ]; then
			(
				set -x
				mkdir -p "$dir"
			)
		fi

		if [ -z "$architecture" ]; then
			get_arch
		fi

		case "$architecture" in
			amd64|x86_64)
				download_file "$JQ_LINUX64_URL" "$JQ_BIN" "$JQ_LINUX64_HASH"
				;;
			i386|i486|i586|i686|x86)
				download_file "$JQ_LINUX32_URL" "$JQ_BIN" "$JQ_LINUX32_HASH"
				;;
		esac

		if ! check_jq; then
			cat >&2 <<-EOF
			未找到适用于当前系统的 JSON 解析软件 jq
			EOF
			exit 1
		fi

		return 0
	fi
}

# 读取 json 文件中某一项的值
get_json_string() {
	install_jq

	local content="$1"
	local selector="$2"
	local regex="$3"

	local str=""
	if [ -n "$content" ]; then
		str="$(echo "$content" | $JQ_BIN -r "$selector" 2>/dev/null)"

		if [ -n "$str" ] && [ -n "$regex" ]; then
			str="$(echo "$str" | grep -oE "$regex")"
		fi
	fi
	echo "$str"
}

# 获取当前实例的配置文件路径，传入参数：
# * config: passwall服务端配置文件
# * log: passwall 日志文件路径
# * snmp: passwall snmp 日志文件路径
# * supervisor: 实例的 supervisor 文件路径
get_current_file() {
	case "$1" in
		config)
			printf '%s/server-config%s.json' "$INSTALL_DIR" "$current_instance_id"
			;;
		log)
			printf '%s/server%s.log' "$LOG_DIR" "$current_instance_id"
			;;
		snmp)
			printf '%s/snmplog%s.log' "$LOG_DIR" "$current_instance_id"
			;;
		supervisor)
			printf '/etc/supervisor/conf.d/passwall%s.conf' "$current_instance_id"
			;;
	esac
}

# 获取实例数量
get_instance_count() {
	if [ -d '/etc/supervisor/conf.d/' ]; then
		ls -l '/etc/supervisor/conf.d/' | grep "^-" | awk '{print $9}' | grep -cP "^passwall\d*\.conf$"
	else
		echo "0"
	fi
}

# 通过 API 获取对应版本号 的 release 信息
# 传入 版本号
get_version_info() {
	local request_version="$1"

	local version_content=""
	if [ -n "$request_version" ]; then
		local json_content=""
		json_content="$(get_content "$RELEASES_URL")"
		local version_selector=".[] | select(.tag_name == \"${request_version}\")"
		version_content="$(get_json_string "$json_content" "$version_selector")"
	else
		version_content="$(get_content "$LATEST_RELEASE_URL")"
	fi

	if [ -z "$version_content" ]; then
		return 1
	fi

	if [ -z "$spruce_type" ]; then
		get_arch
	fi

	local url_selector=".assets[] | select(.name | contains(\"${spruce_type}\")) | .browser_download_url"
	release_download_url="$(get_json_string "$version_content" "$url_selector")"

	if [ -z "$release_download_url" ]; then
		return 1
	fi

	release_tag_name="$(get_json_string "$version_content" '.tag_name')"
	release_name="$(get_json_string "$version_content" '.name')"
	release_prerelease="$(get_json_string "$version_content" '.prerelease')"
	release_publish_time="$(get_json_string "$version_content" '.published_at')"
	release_html_url="$(get_json_string "$version_content" '.html_url')"

	local body_content="$(get_json_string "$version_content" '.body')"
	local body="$(echo "$body_content" | sed 's/#br#/\n/g' | grep -vE '(^```)|(^>)|(^[[:space:]]*$)|(SUM$)')"

	release_body="$(echo "$body" | grep -vE "[0-9a-zA-Z]{32,}")"

	local file_verify=""
	file_verify="$(echo "$body" | grep "$spruce_type")"

	if [ -n "$file_verify" ]; then
		local i="1"
		local split=""
		while true
		do
			split="$(echo "$file_verify" | cut -d ' ' -f$i)"

			if [ -n "$split" ] && ( echo "$split" | grep -qE "^[0-9a-zA-Z]{32,}$" ); then
				kcptun_release_verify="$split"
				break
			elif [ -z "$split" ]; then
				break
			fi

			i=$(expr $i + 1)
		done
	fi

	return 0
}

# 获取脚本版本信息
get_shell_version_info() {
	local shell_version_content=""
	shell_version_content="$(get_content "$SHELL_VERSION_INFO_URL")"
	if [ -z "$shell_version_content" ]; then
		return 1
	fi

	new_shell_version="$(get_json_string "$shell_version_content" '.shell_version' '[0-9]+')"
	new_config_version="$(get_json_string "$shell_version_content" '.config_version' '[0-9]+')"
	new_init_version="$(get_json_string "$shell_version_content" '.init_version' '[0-9]+')"

	shell_change_log="$(get_json_string "$shell_version_content" '.change_log')"
	config_change_log="$(get_json_string "$shell_version_content" '.config_change_log')"
	init_change_log="$(get_json_string "$shell_version_content" '.init_change_log')"
	new_shell_url="$(get_json_string "$shell_version_content" '.shell_url')"


	if [ -z "$new_shell_version" ]; then
		new_shell_version="0"
	fi
	if [ -z "$new_config_version" ]; then
		new_config_version="0"
	fi
	if [ -z "$new_init_version" ]; then
		new_init_version="0"
	fi

	return 0
}

# 下载并安装 
install() {
	if [ -z "$release_download_url" ]; then
		get_version_info "$1"

		if [ "$?" != "0" ]; then
			cat >&2 <<-'EOF'
			获取版本信息或下载地址失败!
			可能是 GitHub 改版，或者从网络获取到的内容不正确。
			请联系脚本作者。
			EOF
			exit 1
		fi
	fi

	local file_name="kcptun-${release_tag_name}.tar.gz"
	download_file "$release_download_url" "$file_name" "$release_verify"

	if [ ! -d "$INSTALL_DIR" ]; then
		(
			set -x
			mkdir -p "$INSTALL_DIR"
		)
	fi

	if [ ! -d "$LOG_DIR" ]; then
		(
			set -x
			mkdir -p "$LOG_DIR"
			chmod a+w "$LOG_DIR"
		)
	fi

	(
		set -x
		tar -zxf "$file_name" -C "$INSTALL_DIR"
		sleep 5
	)

	local server_file=""
	server_file="$(get_server_file)"

	if [ ! -f "$server_file" ]; then
		cat >&2 <<-'EOF'
		未在解压文件中找到服务端执行文件!
		通常这不会发生，可能的原因是作者打包文件的时候更改了文件名。
		你可以尝试重新安装，或者联系脚本作者。
		EOF
		exit 1
	fi

	chmod a+x "$server_file"

	if [ -z "$(get_installed_version)" ]; then
		cat >&2 <<-'EOF'
		无法找到适合当前服务器的可执行文件
		你可以尝试从源码编译。
		EOF
		exit 1
	fi

	rm -f "$file_name" "${INSTALL_DIR}/client_$file_suffix"
}

# 安装依赖软件
install_deps() {
	if [ -z "$lsb_dist" ]; then
		get_os_info
	fi

	case "$lsb_dist" in
		ubuntu|debian|raspbian)
			local did_apt_get_update=""
			apt_get_update() {
				if [ -z "$did_apt_get_update" ]; then
					( set -x; sleep 3; apt-get update )
					did_apt_get_update=1
				fi
			}

			if ! command_exists wget; then
				apt_get_update
				( set -x; sleep 3; apt-get install -y -q wget ca-certificates )
			fi

			if ! command_exists awk; then
				apt_get_update
				( set -x; sleep 3; apt-get install -y -q gawk )
			fi

			if ! command_exists tar; then
				apt_get_update
				( set -x; sleep 3; apt-get install -y -q tar )
			fi

			if ! command_exists pip; then
				apt_get_update
				( set -x; sleep 3; apt-get install -y -q python-pip || true )
			fi

			if ! command_exists python; then
				apt_get_update
				( set -x; sleep 3; apt-get install -y -q python )
			fi
			;;
		fedora|centos|redhat|oraclelinux|photon)
			if [ "$lsb_dist" = "fedora" ] && [ "$dist_version" -ge "22" ]; then
				if ! command_exists wget; then
					( set -x; sleep 3; dnf -y -q install wget ca-certificates )
				fi

				if ! command_exists awk; then
					( set -x; sleep 3; dnf -y -q install gawk )
				fi

				if ! command_exists tar; then
					( set -x; sleep 3; dnf -y -q install tar )
				fi

				if ! command_exists pip; then
					( set -x; sleep 3; dnf -y -q install python-pip || true )
				fi

				if ! command_exists python; then
					( set -x; sleep 3; dnf -y -q install python )
				fi
			elif [ "$lsb_dist" = "photon" ]; then
				if ! command_exists wget; then
					( set -x; sleep 3; tdnf -y install wget ca-certificates )
				fi

				if ! command_exists awk; then
					( set -x; sleep 3; tdnf -y install gawk )
				fi

				if ! command_exists tar; then
					( set -x; sleep 3; tdnf -y install tar )
				fi

				if ! command_exists pip; then
					( set -x; sleep 3; tdnf -y install python-pip || true )
				fi

				if ! command_exists python; then
					( set -x; sleep 3; tdnf -y install python )
				fi
			else
				if ! command_exists wget; then
					( set -x; sleep 3; yum -y -q install wget ca-certificates )
				fi

				if ! command_exists awk; then
					( set -x; sleep 3; yum -y -q install gawk )
				fi

				if ! command_exists tar; then
					( set -x; sleep 3; yum -y -q install tar )
				fi

				# CentOS 等红帽系操作系统的软件库中可能不包括 python-pip
				# 可以先安装 epel-release
				if ! command_exists pip; then
					( set -x; sleep 3; yum -y -q install python-pip || true )
				fi

				# 如果 python-pip 安装失败，检测是否已安装 python 环境
				if ! command_exists python; then
					( set -x; sleep 3; yum -y -q install python )
				fi
			fi
			;;
		*)
			cat >&2 <<-EOF
			暂时不支持当前系统：${lsb_dist} ${dist_version}
			EOF

			exit 1
			;;
	esac

	# 这里判断了是否存在安装失败的软件包，但是默认不处理 python-pip 的安装失败，
	# 接下来会统一检测并再次安装 pip 命令
	if [ "$?" != 0 ]; then
		cat >&2 <<-'EOF'
		一些依赖软件安装失败，
		请查看日志检查错误。
		EOF
		exit 1
	fi

	install_jq
}

# 安装 supervisor
install_supervisor() {
	if [ -s /etc/supervisord.conf ] && command_exists supervisord; then
		cat >&2 <<-EOF
		检测到你曾经通过其他方式安装过 Supervisor , 这会和本脚本安装的 Supervisor 产生冲突
		推荐你备份当前 Supervisor 配置后卸载原有版本
		已安装的 Supervisor 配置文件路径为: /etc/supervisord.conf
		通过本脚本安装的 Supervisor 配置文件路径为: /etc/supervisor/supervisord.conf
		你可以使用以下命令来备份原有配置文件:
		    mv /etc/supervisord.conf /etc/supervisord.conf.bak
		EOF

		exit 1
	fi

	if ! command_exists python; then
		cat >&2 <<-'EOF'
		python 环境未安装，并且自动安装失败，请手动安装 python 环境。
		EOF

		exit 1
	fi

	local python_version="$(python -V 2>&1)"

	if [ "$?" != "0" ] || [ -z "$python_version" ]; then
		cat >&2 <<-'EOF'
		python 环境已损坏，无法通过 python -V 来获取版本号。
		请手动重装 python 环境。
		EOF

		exit 1
	fi

	local version_string="$(echo "$python_version" | cut -d' ' -f2 | head -n1)"
	local major_version="$(echo "$version_string" | cut -d'.' -f1)"
	local minor_version="$(echo "$version_string" | cut -d'.' -f2)"

	if [ -z "$major_version" ] || [ -z "$minor_version" ] || \
		! ( is_number "$major_version" ); then
		cat >&2 <<-EOF
		获取 python 大小版本号失败：${python_version}
		EOF

		exit 1
	fi

	local is_python_26="false"

	if [ "$major_version" -lt "2" ] || ( \
		[ "$major_version" = "2" ] && [ "$minor_version" -lt "6" ] ); then
		cat >&2 <<-EOF
		不支持的 python 版本 ${version_string}，当前仅支持 python 2.6 及以上版本的安装。
		EOF

		exit 1
	elif [ "$major_version" = "2" ] && [ "$minor_version" = "6" ]; then
		is_python_26="true"

		cat >&1 <<-EOF
		注意：当前服务器的 python 版本为 ${version_string},
		脚本对 python 2.6 及以下版本的支持可能会失效，
		请尽快升级 python 版本到 >= 2.7.9 或 >= 3.4。
		EOF

		any_key_to_continue
	fi

	if ! command_exists pip; then
		# 如果没有监测到 pip 命令，但当前服务器已经安装 python
		# 使用 get-pip.py 脚本来安装 pip 命令
		if [ "$is_python_26" = "true" ]; then
			(
				set -x
				wget -qO- --no-check-certificate https://bootstrap.pypa.io/2.6/get-pip.py | python
			)
		else
			(
				set -x
				wget -qO- --no-check-certificate https://bootstrap.pypa.io/get-pip.py | python
			)
		fi
	fi

	# 如果使用脚本安装依然失败，提示手动安装
	if ! command_exists pip; then
		cat >&2 <<-EOF
		未找到已安装的 pip 命令，请先手动安装 python-pip
		本脚本自 v21 版开始使用 pip 来安装 Supervisior。
		1. 对于 Debian 系的 Linux 系统，可以尝试使用：
		  sudo apt-get install -y python-pip 来进行安装
		2. 对于 Redhat 系的 Linux 系统，可以尝试使用：
		  sudo yum install -y python-pip 来进行安装
		  * 如果提示未找到，可以先尝试安装：epel-release 扩展软件库
		3. 如果以上方法都失败了，请使用以下命令来手动安装：
		  wget -qO- --no-check-certificate https://bootstrap.pypa.io/get-pip.py | python
		  * python 2.6 的用户请使用：
		    wget -qO- --no-check-certificate https://bootstrap.pypa.io/2.6/get-pip.py | python
		4. pip 安装完毕之后，先运行一下更新命令：
		  pip install --upgrade pip
		  再检查一下 pip 的版本：
		  pip -V
		一切无误后，请重新运行安装脚本。
		EOF
		exit 1
	fi

	if ! ( pip --version >/dev/null 2>&1 ); then
		cat >&2 <<-EOF
		检测到当前环境的 pip 命令已损坏，
		请检查你的 python 环境。
		EOF

		exit 1
	fi

	if [ "$is_python_26" != "true" ]; then
		# 已安装 pip 时先尝试更新一下，
		# 如果是 python 2.6，就不要更新了，更新会导致 pip 损坏
		# pip 只支持 python 2 >= 2.7.9
		# https://pip.pypa.io/en/stable/installing/
		(
			set -x
			pip install --upgrade pip || true
		)
	fi

	if [ "$is_python_26" = "true" ]; then
		(
			set -x
			pip install 'supervisor>=3.0.0,<4.0.0'
		)
	else
		(
			set -x
			pip install --upgrade supervisor
		)
	fi

	if [ "$?" != "0" ]; then
		cat >&2 <<-EOF
		错误: 安装 Supervisor 失败，
		请尝试使用
		  pip install supervisor
		来手动安装。
		Supervisor 从 4.0 开始已不支持 python 2.6 及以下版本
		python 2.6 的用户请使用：
		  pip install 'supervisor>=3.0.0,<4.0.0'
		EOF

		exit 1
	fi

	[ ! -d /etc/supervisor/conf.d ] && (
		set -x
		mkdir -p /etc/supervisor/conf.d
	)

	if [ ! -f '/usr/local/bin/supervisord' ]; then
		(
			set -x
			ln -s "$(command -v supervisord)" '/usr/local/bin/supervisord' 2>/dev/null
		)
	fi

	if [ ! -f '/usr/local/bin/supervisorctl' ]; then
		(
			set -x
			ln -s "$(command -v supervisorctl)" '/usr/local/bin/supervisorctl' 2>/dev/null
		)
	fi

	if [ ! -f '/usr/local/bin/pidproxy' ]; then
		(
			set -x
			ln -s "$(command -v pidproxy)" '/usr/local/bin/pidproxy' 2>/dev/null
		)
	fi

	local cfg_file='/etc/supervisor/supervisord.conf'

	local rvt="0"

	if [ ! -s "$cfg_file" ]; then
		if ! command_exists echo_supervisord_conf; then
			cat >&2 <<-'EOF'
			未找到 echo_supervisord_conf, 无法自动创建 Supervisor 配置文件!
			可能是当前安装的 supervisor 版本过低。
			EOF
			exit 1
		fi

		(
			set -x
			echo_supervisord_conf >"$cfg_file" 2>&1
		)
		rvt="$?"
	fi

	local cfg_content="$(cat "$cfg_file")"

	# Error with supervisor config file
	if ( echo "$cfg_content" | grep -q "Traceback (most recent call last)" ) ; then
		rvt="1"

		if ( echo "$cfg_content" | grep -q "DistributionNotFound: meld3" ); then
			# https://github.com/Supervisor/meld3/issues/23
			(
				set -x
				local temp="$(mktemp -d)"
				local pwd="$(pwd)"

				download_file 'https://pypi.python.org/packages/source/m/meld3/meld3-1.0.2.tar.gz' \
					"$temp/meld3.tar.gz"

				cd "$temp"
				tar -zxf "$temp/meld3.tar.gz" --strip=1
				python setup.py install
				cd "$pwd"
			)

			if [ "$?" = "0" ] ; then
				(
					set -x
					echo_supervisord_conf >"$cfg_file" 2>/dev/null
				)
				rvt="$?"
			fi
		fi
	fi

	if [ "$rvt" != "0" ]; then
		rm -f "$cfg_file"
		echo "创建 Supervisor 配置文件失败!"
		exit 1
	fi

	if ! grep -q '^files[[:space:]]*=[[:space:]]*/etc/supervisor/conf.d/\*\.conf$' "$cfg_file"; then
		if grep -q '^\[include\]$' "$cfg_file"; then
			sed -i '/^\[include\]$/a files = \/etc\/supervisor\/conf.d\/\*\.conf' "$cfg_file"
		else
			sed -i '$a [include]\nfiles = /etc/supervisor/conf.d/*.conf' "$cfg_file"
		fi
	fi

	download_startup_file
}

download_startup_file() {
	local supervisor_startup_file=""
	local supervisor_startup_file_url=""

	if command_exists systemctl; then
		supervisor_startup_file="/etc/systemd/system/supervisord.service"
		supervisor_startup_file_url="$SUPERVISOR_SYSTEMD_FILE_URL"

		download_file "$supervisor_startup_file_url" "$supervisor_startup_file"
		(
			set -x
			# 删除旧版 service 文件

			local old_service_file="/lib/systemd/system/supervisord.service"
			if [ -f "$old_service_file" ]; then
				rm -f "$old_service_file"
			fi
			systemctl daemon-reload >/dev/null 2>&1
		)
	elif command_exists service; then
		supervisor_startup_file='/etc/init.d/supervisord'

		if [ -z "$lsb_dist" ]; then
			get_os_info
		fi

		case "$lsb_dist" in
			ubuntu|debian|raspbian)
				supervisor_startup_file_url="$SUPERVISOR_SERVICE_FILE_DEBIAN_URL"
				;;
			fedora|centos|redhat|oraclelinux|photon)
				supervisor_startup_file_url="$SUPERVISOR_SERVICE_FILE_REDHAT_URL"
				;;
			*)
				echo "没有适合当前系统的服务启动脚本文件。"
				exit 1
				;;
		esac

		download_file "$supervisor_startup_file_url" "$supervisor_startup_file"
		(
			set -x
			chmod a+x "$supervisor_startup_file"
		)
	else
		cat >&2 <<-'EOF'
		当前服务器未安装 systemctl 或者 service 命令，无法配置服务。
		请先手动安装 systemd 或者 service 之后再运行脚本。
		EOF

		exit 1
	fi
}

start_supervisor() {
	( set -x; sleep 3 )
	if command_exists systemctl; then
		if systemctl status supervisord.service >/dev/null 2>&1; then
			systemctl restart supervisord.service
		else
			systemctl start supervisord.service
		fi
	elif command_exists service; then
		if service supervisord status >/dev/null 2>&1; then
			service supervisord restart
		else
			service supervisord start
		fi
	fi

	if [ "$?" != "0" ]; then
		cat >&2 <<-'EOF'
		启动 Supervisor 失败, 无法正常工作!
		请反馈给脚本作者。
		EOF
		exit 1
	fi
}

enable_supervisor() {
	if command_exists systemctl; then
		(
			set -x
			systemctl enable "supervisord.service"
		)
	elif command_exists service; then
		if [ -z "$lsb_dist" ]; then
			get_os_info
		fi

		case "$lsb_dist" in
			ubuntu|debian|raspbian)
				(
					set -x
					update-rc.d -f supervisord defaults
				)
				;;
			fedora|centos|redhat|oraclelinux|photon)
				(
					set -x
					chkconfig --add supervisord
					chkconfig supervisord on
				)
				;;
			esac
	fi
}

set_config() {

	cat >&2 <<-'EOF'
 #作者很懒，还没有写
		EOF
}

# 生成服务端配置文件
gen_config() {
	mk_file_dir() {
		local dir=""
		dir="$(dirname "$1")"
		local mod=$2

		if [ ! -d "$dir" ]; then
			(
				set -x
				mkdir -p "$dir"
			)
		fi

		if [ -n "$mod" ]; then
			chmod $mod "$dir"
		fi
	}

	local config_file=""
	config_file="$(get_current_file 'config')"
	local supervisor_config_file=""
	supervisor_config_file="$(get_current_file 'supervisor')"

	mk_file_dir "$config_file"
	mk_file_dir "$supervisor_config_file"


	cat > "$config_file"<<-EOF
	{
  #作者很懒，还没有写
	}
	EOF

	write_configs_to_file() {
		install_jq
		local k; local v

		local json=""
		json="$(cat "$config_file")"
		for k in "$@"; do
			v="$(eval echo "\$$k")"

			if [ -n "$v" ]; then
				if is_number "$v" || [ "$v" = "false" ] || [ "$v" = "true" ]; then
					json="$(echo "$json" | $JQ_BIN ".$k=$v")"
				else
					json="$(echo "$json" | $JQ_BIN ".$k=\"$v\"")"
				fi
			fi
		done

		if [ -n "$json" ] && [ "$json" != "$(cat "$config_file")" ]; then
			echo "$json" >"$config_file"
		fi
	}
  
  #write_configs_to_file 作者没有想好
  
	if ! grep -q "^${run_user}:" '/etc/passwd'; then
		(
			set -x
			useradd -U -s '/usr/sbin/nologin' -d '/nonexistent' "$run_user" 2>/dev/null
		)
	fi

	cat > "$supervisor_config_file"<<-EOF
	[program:passwall${current_instance_id}]
	user=${run_user}
	directory=${INSTALL_DIR}
	command=$(get_server_file) -c "${config_file}"
	process_name=%(program_name)s
	autostart=true
	redirect_stderr=true
	stdout_logfile=$(get_current_file 'log')
	stdout_logfile_maxbytes=1MB
	stdout_logfile_backups=0
	EOF
}

# 设置防火墙开放端口
set_firewall() {
	if command_exists firewall-cmd; then
		if ! ( firewall-cmd --state >/dev/null 2>&1 ); then
			systemctl start firewalld >/dev/null 2>&1
		fi
		if [ "$?" = "0" ]; then
			if [ -n "$current_listen_port" ]; then
				firewall-cmd --zone=public --remove-port=${current_listen_port}/udp >/dev/null 2>&1
			fi

			if ! firewall-cmd --quiet --zone=public --query-port=${listen_port}/udp; then
				firewall-cmd --quiet --permanent --zone=public --add-port=${listen_port}/udp
				firewall-cmd --reload
			fi
		else
			cat >&1 <<-EOF
			警告: 自动添加 firewalld 规则失败
			如果有必要, 请手动添加端口 ${listen_port} 的防火墙规则:
			    firewall-cmd --permanent --zone=public --add-port=${listen_port}/udp
			    firewall-cmd --reload
			EOF
		fi
	elif command_exists iptables; then
		if ! ( service iptables status >/dev/null 2>&1 ); then
			service iptables start >/dev/null 2>&1
		fi

		if [ "$?" = "0" ]; then
			if [ -n "$current_listen_port" ]; then
				iptables -D INPUT -p udp --dport ${current_listen_port} -j ACCEPT >/dev/null 2>&1
			fi

			if ! iptables -C INPUT -p udp --dport ${listen_port} -j ACCEPT >/dev/null 2>&1; then
				iptables -I INPUT -p udp --dport ${listen_port} -j ACCEPT >/dev/null 2>&1
				service iptables save
				service iptables restart
			fi
		else
			cat >&1 <<-EOF
			警告: 自动添加 iptables 规则失败
			如有必要, 请手动添加端口 ${listen_port} 的防火墙规则:
			    iptables -I INPUT -p udp --dport ${listen_port} -j ACCEPT
			    service iptables save
			    service iptables restart
			EOF
		fi
	fi
}

# 选择一个实例
select_instance() {
	if [ "$(get_instance_count)" -gt 1 ]; then
		cat >&1 <<-'EOF'
		当前有多个 实例 (按最后修改时间排序):
		EOF

		local files=""
		files=$(ls -lt '/etc/supervisor/conf.d/' | grep "^-" | awk '{print $9}' | grep "^passwall[0-9]*\.conf$")
		local i=0
		local array=""
		local id=""
		for file in $files; do
			id="$(echo "$file" | grep -oE "[0-9]+")"
			array="${array}${id}#"

			i=$(expr $i + 1)
			echo "(${i}) ${file%.*}"
		done

		local sel=""
		while true
		do
			read -p "请选择 [1~${i}]: " sel
			if [ -n "$sel" ]; then
				if ! is_number "$sel" || [ $sel -lt 1 ] || [ $sel -gt $i ]; then
					cat >&2 <<-EOF
					请输入有效数字 1~${i}!
					EOF
					continue
				fi
			else
				cat >&2 <<-EOF
				请输入不能为空！
				EOF
				continue
			fi

			current_instance_id=$(echo "$array" | cut -d '#' -f ${sel})
			break
		done
	fi
}

# 通过当前服务端环境获取服务端文件名
get_server_file() {
	if [ -z "$file_suffix" ]; then
		get_arch
	fi

	echo "${INSTALL_DIR}/server_$file_suffix"
}

# 计算新实例的 ID
get_new_instance_id() {
	if [ -f "/etc/supervisor/conf.d/passwall.conf" ]; then
		local i=2
		while [ -f "/etc/supervisor/conf.d/passwall${i}.conf" ]
		do
			i=$(expr $i + 1)
		done
		echo "$i"
	fi
}

# 获取已安装的Passwall 版本
get_installed_version() {
	local server_file=""
	server_file="$(get_server_file)"

	if [ -f "$server_file" ]; then
		if [ ! -x "$server_file" ]; then
			chmod a+x "$server_file"
		fi

		echo "$(${server_file} -v 2>/dev/null | awk '{print $3}')"
	fi
}

# 加载当前选择实例的配置文件
load_instance_config() {
	local config_file=""
	config_file="$(get_current_file 'config')"

	if [ ! -s "$config_file" ]; then
		cat >&2 <<-'EOF'
		实例配置文件不存在或为空, 请检查!
		EOF
		exit 1
	fi

	local config_content=""
	config_content="$(cat ${config_file})"

	if [ -z "$(get_json_string "$config_content" '.listen')" ]; then
		cat >&2 <<-EOF
		实例配置文件存在错误, 请检查!
		配置文件路径: ${config_file}
		EOF
		exit 1
	fi

	local lines=""
	lines="$(get_json_string "$config_content" 'to_entries | map("\(.key)=\(.value | @sh)") | .[]')"

	OLDIFS=$IFS
	IFS=$(printf '\n')
	for line in $lines; do
		eval "$line"
	done
	IFS=$OLDIFS

	if [ -n "$listen" ]; then
		listen_port="$(echo "$listen" | rev | cut -d ':' -f1 | rev)"
		listen_addr="$(echo "$listen" | sed "s/:${listen_port}$//" | grep -oE '[0-9a-fA-F\.:]*')"
		listen=""
	fi
	if [ -n "$target" ]; then
		target_port="$(echo "$target" | rev | cut -d ':' -f1 | rev)"
		target_addr="$(echo "$target" | sed "s/:${target_port}$//" | grep -oE '[0-9a-fA-F\.:]*')"
		target=""
	fi

	if [ -n "$listen_port" ]; then
		current_listen_port="$listen_port"
	fi
}

# 显示服务端版本，和客户端文件的下载地址
show_version_and_client_url() {
	local version=""
	version="$(get_installed_version)"
	if [ -n "$version" ]; then
		cat >&1 <<-EOF
		当前安装的版本为: ${version}
		EOF
	fi

	if [ -n "$release_html_url" ]; then
		cat >&1 <<-EOF
		请自行前往:
		  ${release_html_url}
		手动下载客户端文件
		EOF
	fi
}

# 显示当前选择实例的信息
show_current_instance_info() {
	local server_ip=""
	server_ip="$(get_server_ip)"

	printf '服务器IP: \033[41;37m %s \033[0m\n' "$server_ip"
	printf '端口: \033[41;37m %s \033[0m\n' "$listen_port"
	printf '加速地址: \033[41;37m %s:%s \033[0m\n' "$target_addr" "$target_port"

	show_configs() {
		local k; local v
		for k in "$@"; do
			v="$(eval echo "\$$k")"
			if [ -n "$v" ]; then
				printf '%s: \033[41;37m %s \033[0m\n' "$k" "$v"
			fi
		done
	}

#	show_configs 还没有写呢

	show_version_and_client_url

	install_jq
	local client_config=""

	# 这里输出的是客户端所使用的配置信息
	# 客户端的 *remoteaddr* 端口号为服务端的 *listen_port*
	# 客户端的 *localaddr* 端口号被设置为了服务端的加速端口
	client_config="$(cat <<-EOF
	{
	  "localaddr": ":${target_port}",
	  "remoteaddr": "${server_ip}:${listen_port}",
	  "key": "${key}"
	}
	EOF
	)"

	gen_client_configs() {
  
	#还没有写
	}

 #gen_client_configs 

	cat >&1 <<-EOF
	可使用的客户端配置文件为:
	${client_config}
	EOF

	local mobile_config="key=${key}"
	gen_mobile_configs() {
		#还没有写
	}

	#gen_mobile_configs

	cat >&1 <<-EOF
	手机端参数可以使用:
	  ${mobile_config}
	EOF
}

do_install() {
	check_root
	disable_selinux
	installed_check
	#set_config
	install_deps
	#install_passwall
	#install_supervisor
	#gen_config
	#set_firewall
	#start_supervisor
	#enable_supervisor

	cat >&1 <<-EOF
	恭喜! 服务端安装成功。
	EOF

	#show_current_instance_info

	cat >&1 <<-EOF
	安装目录: ${INSTALL_DIR}
	#已将 Supervisor 加入开机自启,
	#服务端会随 Supervisor 的启动而启动
	更多使用说明: ${0} help
	EOF
}

# 卸载操作
do_uninstall() {
	check_root
	cat >&1 <<-'EOF'
	你选择了卸载Passwall 服务端
	EOF
	any_key_to_continue
	echo "正在卸载 Passwall 服务端并停止 Supervisor..."

	if command_exists supervisorctl; then
		supervisorctl shutdown
	fi

	if command_exists systemctl; then
		systemctl stop supervisord.service
	elif command_exists serice; then
		service supervisord stop
	fi

	(
		set -x
		rm -f "/etc/supervisor/conf.d/passwall*.conf"
		rm -rf "$INSTALL_DIR"
		rm -rf "$LOG_DIR"
	)

	cat >&1 <<-'EOF'
	是否同时卸载 Supervisor ?
	注意: Supervisor 的配置文件将同时被删除
	EOF

	read -p "(默认: 不卸载) 请选择 [y/n]: " yn
	if [ -n "$yn" ]; then
		case "$(first_character "$yn")" in
			y|Y)
				if command_exists systemctl; then
					systemctl disable supervisord.service
					rm -f "/lib/systemd/system/supervisord.service" \
						"/etc/systemd/system/supervisord.service"
				elif command_exists service; then
					if [ -z "$lsb_dist" ]; then
						get_os_info
					fi
					case "$lsb_dist" in
						ubuntu|debian|raspbian)
							(
								set -x
								update-rc.d -f supervisord remove
							)
							;;
						fedora|centos|redhat|oraclelinux|photon)
							(
								set -x
								chkconfig supervisord off
								chkconfig --del supervisord
							)
							;;
					esac
					rm -f '/etc/init.d/supervisord'
				fi

				(
					set -x
					# 新版使用 pip 卸载
					if command_exists pip; then
						pip uninstall -y supervisor 2>/dev/null || true
					fi

					# 旧版使用 easy_install 卸载
					if command_exists easy_install; then
						rm -rf "$(easy_install -mxN supervisor | grep 'Using.*supervisor.*\.egg' | awk '{print $2}')"
					fi

					rm -rf '/etc/supervisor/'
					rm -f '/usr/local/bin/supervisord' \
						'/usr/local/bin/supervisorctl' \
						'/usr/local/bin/pidproxy' \
						'/usr/local/bin/echo_supervisord_conf' \
						'/usr/bin/supervisord' \
						'/usr/bin/supervisorctl' \
						'/usr/bin/pidproxy' \
						'/usr/bin/echo_supervisord_conf'
				)
				;;
			n|N|*)
				start_supervisor
				;;
		esac
	fi

	cat >&1 <<-EOF
	卸载完成, 欢迎再次使用。
	注意: 脚本没有自动卸载 python-pip 和 python-setuptools（旧版脚本使用）
	如有需要, 你可以自行卸载。
	EOF
}

# 更新
do_update() {
	pre_ckeck

	cat >&1 <<-EOF
	你选择了检查更新, 正在开始操作...
	EOF

	if get_shell_version_info; then
		local shell_path=$0

		if [ $new_shell_version -gt $SHELL_VERSION ]; then
			cat >&1 <<-EOF
			发现一键安装脚本更新, 版本号: ${new_shell_version}
			更新说明:
			$(printf '%s\n' "$shell_change_log")
			EOF
			any_key_to_continue

			mv -f "$shell_path" "$shell_path".bak

			download_file "$new_shell_url" "$shell_path"
			chmod a+x "$shell_path"

			sed -i -r "s/^CONFIG_VERSION=[0-9]+/CONFIG_VERSION=${CONFIG_VERSION}/" "$shell_path"
			sed -i -r "s/^INIT_VERSION=[0-9]+/INIT_VERSION=${INIT_VERSION}/" "$shell_path"
			rm -f "$shell_path".bak

			clear
			cat >&1 <<-EOF
			安装脚本已更新到 v${new_shell_version}, 正在运行新的脚本...
			EOF

			bash "$shell_path" update
			exit 0
		fi

		if [ $new_config_version -gt $CONFIG_VERSION ]; then
			cat >&1 <<-EOF
			发现配置更新, 版本号: v${new_config_version}
			更新说明:
			$(printf '%s\n' "$config_change_log")
			需要重新设置
			EOF
			any_key_to_continue

			instance_reconfig

			sed -i "s/^CONFIG_VERSION=${CONFIG_VERSION}/CONFIG_VERSION=${new_config_version}/" \
				"$shell_path"
		fi

		if [ $new_init_version -gt $INIT_VERSION ]; then
			cat >&1 <<-EOF
			发现服务启动脚本文件更新, 版本号: v${new_init_version}
			更新说明:
			$(printf '%s\n' "$init_change_log")
			EOF

			any_key_to_continue

			download_startup_file
			set -sed -i "s/^INIT_VERSION=${INIT_VERSION}/INIT_VERSION=${new_init_version}/" \
				"$shell_path"
		fi
	fi

	echo "开始获取版本信息..."
	get_version_info

	local cur_tag_name=""
	cur_tag_name="$(get_installed_version)"

	if [ -n "$cur_tag_name" ] && is_number "$cur_tag_name" && [ ${#cur_tag_name} -eq 8 ]; then
		cur_tag_name=v"$cur_tag_name"
	fi

	if [ -n "$release_tag_name" ] && [ "$kcptun_release_tag_name" != "$cur_tag_name" ]; then
		cat >&1 <<-EOF
		发现 新版本 ${release_tag_name}
		$([ "$release_prerelease" = "true" ] && printf "\033[41;37m 注意: 该版本为预览版, 请谨慎更新 \033[0m")
		更新说明:
		$(printf '%s\n' "$release_body")
		EOF
		any_key_to_continue

		install_passwall
		start_supervisor

		show_version_and_client_url
	else
		cat >&1 <<-'EOF'
		未发现 Kcptun 更新...
		EOF
	fi
}

# 添加实例
instance_add() {
	pre_ckeck

	cat >&1 <<-'EOF'
	你选择了添加实例, 正在开始操作...
	EOF
	current_instance_id="$(get_new_instance_id)"

	set_config
	gen_config
	set_firewall
	start_supervisor

	cat >&1 <<-EOF
	恭喜, 实例 Passwall${current_instance_id} 添加成功!
	EOF
	show_current_instance_info
}

# 删除实例
instance_del() {
	pre_ckeck

	if [ -n "$1" ]; then
		if is_number "$1"; then
			if [ "$1" != "1" ]; then
				current_instance_id="$1"
			fi
		else
			cat >&2 <<-EOF
			参数有误, 请使用 $0 del <id>
			<id> 为实例ID, 当前共有 $(get_instance_count) 个实例
			EOF

			exit 1
		fi
	fi

	cat >&1 <<-EOF
	你选择了删除实例 Passwall${current_instance_id}
	注意: 实例删除后无法恢复
	EOF
	any_key_to_continue

	# 获取实例的 supervisor 配置文件
	supervisor_config_file="$(get_current_file 'supervisor')"
	if [ ! -f "$supervisor_config_file" ]; then
		echo "你选择的实例 Passwall${current_instance_id} 不存在!"
		exit 1
	fi

	current_config_file="$(get_current_file 'config')"
	current_log_file="$(get_current_file 'log')"
	current_snmp_log_file="$(get_current_file 'snmp')"

	(
		set -x
		rm -f "$supervisor_config_file" \
			"$current_config_file" \
			"$current_log_file" \
			"$current_snmp_log_file"
	)

	start_supervisor

	cat >&1 <<-EOF
	实例 Passwall${current_instance_id} 删除成功!
	EOF
}

# 显示实例信息
instance_show() {
	pre_ckeck

	if [ -n "$1" ]; then
		if is_number "$1"; then
			if [ "$1" != "1" ]; then
				current_instance_id="$1"
			fi
		else
			cat >&2 <<-EOF
			参数有误, 请使用 $0 show <id>
			<id> 为实例ID, 当前共有 $(get_instance_count) 个实例
			EOF

			exit 1
		fi
	fi

	echo "你选择了查看实例 Passwall${current_instance_id} 的配置, 正在读取..."

	load_instance_config

	echo "实例 Passwall${current_instance_id} 的配置信息如下:"
	show_current_instance_info
}

# 显示实例日志
instance_log() {
	pre_ckeck

	if [ -n "$1" ]; then
		if is_number "$1"; then
			if [ "$1" != "1" ]; then
				current_instance_id="$1"
			fi
		else
			cat >&2 <<-EOF
			参数有误, 请使用 $0 log <id>
			<id> 为实例ID, 当前共有 $(get_instance_count) 个实例
			EOF

			exit 1
		fi
	fi

	echo "你选择了查看实例 Passwall${current_instance_id} 的日志, 正在读取..."

	local log_file=""
	log_file="$(get_current_file 'log')"

	if [ -f "$log_file" ]; then
		cat >&1 <<-EOF
		实例 Passwall${current_instance_id} 的日志信息如下:
		注: 日志实时刷新, 按 Ctrl+C 退出日志查看
		EOF
		tail -n 20 -f "$log_file"
	else
		cat >&2 <<-EOF
		未找到实例 Passwall${current_instance_id} 的日志文件...
		EOF
		exit 1
	fi
}

# 重新配置实例
instance_reconfig() {
	pre_ckeck

	if [ -n "$1" ]; then
		if is_number "$1"; then
			if [ "$1" != "1" ]; then
				current_instance_id="$1"
			fi
		else
			cat >&2 <<-EOF
			参数有误, 请使用 $0 reconfig <id>
			<id> 为实例ID, 当前共有 $(get_instance_count) 个实例
			EOF

			exit 1
		fi
	fi

	cat >&1 <<-EOF
	你选择了重新配置实例 Passwall${current_instance_id}, 正在开始操作...
	EOF

	if [ ! -f "$(get_current_file 'supervisor')" ]; then
		cat >&2 <<-EOF
		你选择的实例 Passwall${current_instance_id} 不存在!
		EOF
		exit 1
	fi

	local sel=""
	cat >&1 <<-'EOF'
	请选择操作:
	(1) 重新配置实例所有选项
	(2) 直接修改实例配置文件
	EOF
	read -p "(默认: 1) 请选择: " sel
	echo
	[ -z "$sel" ] && sel="1"

	case "$(first_character "$sel")" in
		2)
			echo "正在打开配置文件, 请手动修改..."
			local config_file=""
			config_file="$(get_current_file 'config')"
			edit_config_file() {
				if [ ! -f "$config_file" ]; then
					return 1
				fi

				if command_exists vim; then
					vim "$config_file"
				elif command_exists vi; then
					vi "$config_file"
				elif command_exists gedit; then
					gedit "$config_file"
				else
					echo "未找到可用的编辑器, 正在进入全新配置..."
					return 1
				fi

				load_instance_config
			}

			if ! edit_config_file; then
				set_config
			fi
			;;
		1|*)
			load_instance_config
			set_config
			;;
	esac

	gen_config
	set_firewall

	if command_exists supervisorctl; then
		supervisorctl restart "passwall${current_instance_id}"

		if [ "$?" != "0" ]; then
			cat >&2 <<-'EOF'
			重启 Supervisor 失败, Kcptun 无法正常工作!
			请查看日志获取原因，或者反馈给脚本作者。
			EOF
			exit 1
		fi
	else
		start_supervisor
	fi

	cat >&1 <<-EOF
	恭喜, 服务端配置已更新!
	EOF
	show_current_instance_info
}

#手动安装
manual_install() {
	pre_ckeck

	cat >&1 <<-'EOF'
	你选择了自定义版本安装, 正在开始操作...
	EOF

	local tag_name="$1"

	while true
	do
		if [ -z "$tag_name" ]; then
			cat >&1 <<-'EOF'
			请输入你想安装的Passwall版本的完整 TAG
			EOF
			read -p "(例如: v20160904): " tag_name
			if [ -z "$tag_name" ]; then
				echo "输入无效, 请重新输入!"
				continue
			fi
		fi

		if [ "$tag_name" = "SNMP_Milestone" ]; then
			echo "不支持此版本, 请重新输入!"
			tag_name=""
			continue
		fi

		local version_num=""
		version_num=$(echo "$tag_name" | grep -oE "[0-9]+" || "0")
		if [ ${#version_num} -eq 8 ] && [ $version_num -le 20200216 ]; then
			echo "不支持安装 v20200216 及以前版本"
			tag_name=""
			continue
		fi

		echo "正在获取信息，请稍候..."
		get_kcptun_version_info "$tag_name"
		if [ "$?" != "0" ]; then
			cat >&2 <<-EOF
			未找到对应版本下载地址 (TAG: ${tag_name}), 请重新输入!
			你可以前往:
			  ${KCPTUN_TAGS_URL}
			查看所有可用 TAG
			EOF
			tag_name=""
			continue
		else
			cat >&1 <<-EOF
			已找到 Kcptun 版本信息, TAG: ${tag_name}
			EOF
			any_key_to_continue

			install_kcptun "$tag_name"
			start_supervisor
			show_version_and_client_url
			break
		fi
	done
}

pre_ckeck() {
	check_root

	if ! is_installed; then
		cat >&2 <<-EOF
		错误: 检测到你还没有安装 Passwall
		或者 Passwall 程序文件已损坏，
		请运行脚本来重新安装 Passwall服务端。
		EOF

		exit 1
	fi
}

# 监测是否安装了 Passwall
is_installed() {
	if [ -d '/usr/share/kcptun' ]; then
		cat >&1 <<-EOF
		检测发现你由旧版升级到了新版
		新版中将默认安装目录设置为了 ${INSTALL_DIR}
		脚本会自动将文件从旧版目录 /usr/share/passwall
		移动到新版目录 ${INSTALL_DIR}
		EOF
		any_key_to_continue
		(
			set -x
			cp -rf '/usr/share/passwall' "$KCPTUN_INSTALL_DIR" && \
				rm -rf '/usr/share/passwall
		)
	fi

	if [ -d '/etc/supervisor/conf.d/' ] && [ -d "$INSTALL_DIR" ] && \
		[ -n "$(get_installed_version)" ]; then
		return 0
	fi

	return 1
}

# 检查是否已经安装
installed_check() {
	local instance_count=""
	instance_count="$(get_instance_count)"
	if is_installed && [ $instance_count -gt 0 ]; then
		cat >&1 <<-EOF
		检测到你已安装Passwall服务端, 已配置的实例个数为 ${instance_count} 个
		EOF
		while true
		do
			cat >&1 <<-'EOF'
			请选择你希望的操作:
			(1) 覆盖安装
			(2) 重新配置
			(3) 添加实例(多端口)
			(4) 检查更新
			(5) 查看配置
			(6) 查看日志输出
			(7) 自定义版本安装
			(8) 删除实例
			(9) 完全卸载
			(10) 退出脚本
			EOF
			read -p "(默认: 1) 请选择 [1~10]: " sel
			[ -z "$sel" ] && sel=1

			case $sel in
				1)
					echo "开始覆盖安装 Passwall服务端..."
					load_instance_config
					return 0
					;;
				2)
					select_instance
					instance_reconfig
					;;
				3)
					instance_add
					;;
				4)
					do_update
					;;
				5)
					select_instance
					instance_show
					;;
				6)
					select_instance
					instance_log
					;;
				7)
					manual_install
					;;
				8)
					select_instance
					instance_del
					;;
				9)
					do_uninstall
					;;
				10)
					;;
				*)
					echo "输入有误, 请输入有效数字 1~10!"
					continue
					;;
			esac

			exit 0
		done
	fi
}

action=${1:-"install"}
case "$action" in
	install|uninstall|update)
		do_${action}
		;;
	add|reconfig|show|log|del)
		instance_${action} "$2"
		;;
	manual)
		manual_install "$2"
		;;
	help)
		usage 0
		;;
	*)
		usage 1
		;;
esac
