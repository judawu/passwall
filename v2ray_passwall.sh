echo -e "本脚本安装一个简单的V2ray"

# 安装su
sudo su 

# 运行下面的指令下载并安装 V2Ray。当 yum 或 apt-get 可用的情况下，此脚本会自动安装 unzip 和 daemon。这两个组件是安装 V2Ray 的必要组件

#此脚本会自动安装以下文件：

#/usr/bin/v2ray/v2ray：V2Ray 程序；
#/usr/bin/v2ray/v2ctl：V2Ray 工具；
#/etc/v2ray/config.json：配置文件；
#/usr/bin/v2ray/geoip.dat：IP 数据文件

#/usr/bin/v2ray/geosite.dat：域名数据文件
#此脚本会配置自动运行脚本。自动运行脚本会在系统重启之后，自动运行 V2Ray。目前自动运行脚本只支持带有 Systemd 的系统，以及 Debian / Ubuntu 全系列。

bash <(curl -L -s https://install.direct/go.sh)
# wget https://install.direct/go.sh
# sudo bash go.sh
#sudo systemctl start v2ray

#运行脚本位于系统的以下位置：

#/etc/systemd/system/v2ray.service: Systemd
#/etc/init.d/v2ray: SysV


#编辑 /etc/v2ray/config.json 文件来配置你需要的代理方式；
#在 Linux 中，配置文件通常位于 /etc/v2ray/config.json 文件。运行 v2ray --config=/etc/v2ray/config.json，或使用 systemd 等工具把 V2Ray 作为服务在后台运行

#2Ray 提供的配置检查功能（test 选项），因为可以检查 JSON 语法错误外的问题
#/usr/bin/v2ray/v2ray -test -config /etc/v2ray/config.json
#运行 service v2ray start 来启动 V2Ray 进程；
#之后可以使用 service v2ray start|stop|status|reload|restart|force-reload 控制 V2Ray 的运行。

#go.sh 参数
#go.sh 支持如下参数，可在手动安装时根据实际情况调整：

#-p 或 --proxy: 使用代理服务器来下载 V2Ray 的文件，格式与 curl 接受的参数一致，比如 "socks5://127.0.0.1:1080" 或 "http://127.0.0.1:3128"。
#-f 或 --force: 强制安装。在默认情况下，如果当前系统中已有最新版本的 V2Ray，go.sh 会在检测之后就退出。如果需要强制重装一遍，则需要指定该参数。
#--version: 指定需要安装的版本，比如 "v1.13"。默认值为最新版本。
#--local: 使用一个本地文件进行安装。如果你已经下载了某个版本的 V2Ray，则可通过这个参数指定一个文件路径来进行安装。
#示例：

#使用地址为 127.0.0.1:1080 的 SOCKS 代理下载并安装最新版本：./go.sh -p socks5://127.0.0.1:1080#
#安装本地的 v1.13 版本：./go.sh --version v1.13 --local /path/to/v2ray.zip


#acme.sh 的依赖项主要是 netcat(nc
sudo apt-get -y install netcat
#执行以下命令，acme.sh 会安装到 ~/.acme.sh 目录下
curl  https://get.acme.sh | sh
#安装成功后执行 source ~/.bashrc 以确保脚本所设置的命令别名生效

#执行以下命令生成证书
apt-get install socat
sudo ~/.acme.sh/acme.sh --issue -d v3.juda.monster --standalone -k ec-256
#sudo ~/.acme.sh/acme.sh --renew -d mydomain.com --force --ecc
# sudo ~/.acme.sh/acme.sh --renew -d mydomain.com --force
安装证书
 sudo ~/.acme.sh/acme.sh --installcert -d v3.juda.monster --fullchainpath /etc/v2ray/v2ray.crt --keypath /etc/v2ray/v2ray.key --ecc
# sudo ~/.acme.sh/acme.sh --installcert -d v3.juda.monster --fullchainpath /etc/v2ray/v2ray.crt --keypath /etc/v2ray/v2ray.key
#测试证书网站https://www.ssllabs.com/ssltest/index.html


#V2Ray 暂时不支持 TLS1.3，如果开启并强制 TLS1.3 会导致 V2Ray 无法连接
#较低版本的nginx的location需要写为 /ray/ 才能正常工作
#如果在设置完成之后不能成功使用，可能是由于 SElinux 机制(如果你是 CentOS 7 的用户请特别留意 SElinux 这一机制)
#阻止了 Nginx 转发向内网的数据。如果是这样的话，在 V2Ray 的日志里不会有访问信息，
#在 Nginx 的日志里会出现大量的 "Permission Denied" 字段，要解决这一问题需要在终端下键入以下命令
#setsebool -P httpd_can_network_connect 1