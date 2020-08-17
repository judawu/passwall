# passwall

1. udpspeed & upd2raw 一键脚本

#请使用这个脚本吧
wget https://raw.githubusercontent.com/judawu/passwall/master/udpspd2raw.sh && chmod +x ./udpspd2raw.sh && bash ./udpspd2raw.sh

#今天20200217终于把这个脚本调试好了，测试是能用的，花了一天的时间，很值得的，至于用法啥的，去看大佬的教材吧。我服务器用的是谷歌云，客户端用的OPENWRT的软路由，不知道会不会被墙。


2. passwall 一键脚本
wget https://raw.githubusercontent.com/judawu/passwall/master/passwall.sh && chmod +x ./passwall.sh && bash ./passwall.sh

#今天20200307 编写了paswall的框架，计划明天先测试V2ray+websokcet+TSL功能，服务器准备新建一个谷歌云，客户端在PXE里面增加一个DEBian 10的系统，只提供自动修改UUID功能

#今天20200725 增加开启V2RAY自带的SS功能（方便苹果IOS客户端利用OUTLINE翻墙），增加SS字符串和二维码生成，只提供修改SS密码功能，新买了一个搬瓦工主机，谷歌云费钱太快，网速也慢

#今天20200817 增加了几个代理的设置，配置了一个Ubuntu的客户端，修改了客户端和服务器的配置，支持了多种通讯协议
