#!/bin/bash

# This function is used to check whether the input is numbers. Accept string arguments and replace numbers with regulars. Then check whether the ${tmp} is null.
checkInt(){
tmp=$(echo $1|sed 's/[0-9]//g')
if [ -n "${tmp}" ]; then
	return 0
else
	return 1
fi
}

# This function is used to execute sudo command.
sudoExec(){
if $sudo_flag; then
	local cmd='sudo '
	cmd+=$@
	eval $cmd
	return $?
else
	eval $1
	return $?
fi
}

installPackage(){
if dpkg --get-selections | grep $1 ; then
	sudoExec 'apt install $1'
fi
}

if [ $USER == "root" -o $UID -eq 0 ];
then
	:
else
    echo -e "\033[1;44;37m请使用管理员权限运行此脚本！\033[0m\n"
    exit
fi

# Detecting sudo status.
if dpkg --get-selections | grep sudo ; then
	sudo_flag=true
else
	sudo_flag=false
fi

installPackage "curl"
installPackage "jq"

# Detect ip address.
geoip=$(curl -s https://api.ip.sb/geoip)
if echo $ip | grep '"country_code":"CN"' >/dev/null 2>&1; then
	CN=true
else
	CN=false
fi

checkPackage='apt search openjdk-8-jdk-headless | grep openjdk-8-jdk-headless'

if ! sudoExec ${checkPackage}; then
	apt_repo='apt install software-properties-common python-software-properties -y'
	sudoExec ${apt_repo}
	sudoExec 'add-apt-repository ppa:openjdk-r/ppa -y'
	if CN; then
		changePPA='sed -i "s/ppa\\.launchpad\\.net/launchpad\\.proxy\\.ustclug\\.org/g" /etc/apt/sources.list.d/openjdk-r-ubuntu-ppa-*.list'
		sudoExec ${changePPA}
	fi
fi

echo 'Check installation status of java. Please note that this script will just check installation status of openjdk-8-jdk-headless.'

# Installing openjdk-8-jdk-headless.
sudoExec 'apt update'

if dpkg --get-selections | grep openjdk-8-jdk-headless; then
	echo -e "\033[1;44;37mPackage openjdk-8-jdk-headless have been installed.\033[0m\n"
else
	echo -e "\033[1;44;37mInstalling openjdk-8-jdk-headless... \033[0m"
	sudoExec 'apt update && apt install -y openjdk-8-jdk-headless'
	echo -e "\033[1;44;37mPackage openjdk-8-jdk-headless installed. \033[0m"
fi

echo -n "Please speicify the path to install minecraft (default:${HOME}/minecraft) :"
read installPath

if [ -z ${installPath} ]; then
    installPath="${HOME}/minecraft"
fi
echo ${installPath} | grep 'minecraft/\?$'
if [ $? -eq 0 ]; then
    installPath=$( echo ${installPath%/minecraf*})
fi

if [ ! -d ${installPath}/minecraft ]; then
    echo "Create minecraft directory."
	mkdir -p ${installPath}/minecraft
fi

cd ${installPath}/minecraft || return 255
if [ $? = 255 ]; then echo "No such Directory!";fi

# Set a flag to detect whether to download a new minecraft server.
if [ -f ./minecraft_server.*.jar ]; then
	tempver=$(find ./minecraft_server.*.jar | awk -F[\.] '{print $2"."$3"."$4}')
	# Store the existed minecraft server version in tempver.
    while true; do
        echo -n "Detect that there exists minecraft_server.${tempver}.jar, do you want to get a new one? (yes/NO):"
        read yn
        if [ -z ${yn} ]; then
            yn='N'
        fi
        case $yn in
            [Yy]* )
                rm minecraft_server.${tempver}.jar
                flag=1
                break
                ;;
            [Nn]* )
                flag=0
                version=${tempver}
                break
                ;;
            * ) echo "Please answer yes or no.";;
        esac
    done
else
	flag=1
fi

# Handle flag.
if [ ${flag} -eq 1 ]; then
	echo -n "Chose the version(default = 1.12.2) you want to use:"
	read version
	if [ -z ${version} ];then
		version='1.12.2'
	fi

    # This download url may be invalid in the future.
	wget --header="Host: s3.amazonaws.com" \
	--header="Connection: keep-alive" \
	--header="Upgrade-Insecure-Requests: 1" \
	--header="User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Safari/537.36" \
	--header="Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8" \
	--header="Accept-Encoding: gzip, deflate, br" \
	--header="Accept-Language: zh-CN,zh;q=0.9,fr;q=0.8,zh-TW;q=0.7" \
	"https://s3.amazonaws.com/Minecraft.Download/versions/${version}/minecraft_server.${version}.jar"
fi

while true
do
	# Use Ctrl + Backspace to delete error input.
	read -p "Set the minimum memory and maximum memory. [example: 512 1024]: " minmem maxmem
	if [ -z ${maxmem} ]; then
		check=0
	elif [ -z ${minmem} ]; then
		check=0
	else
		check=1
	fi
    checkInt ${maxmem}
	maxS=$?
	checkInt ${minmem}
	minS=$?

    if [[ ${maxS} -eq 0 || ${minS} -eq 0 || ${maxmem} -eq 0 || ${minmem} -eq 0 || ${minmem} -gt ${maxmem} ]]; then
        check=0
    else
        check=1
    fi

    if [[ ${check} -eq 0 ]]; then
		echo -e "\nPlease check your input!"
	else
		break
	fi
done

# Check the installation status of expect.
echo "Check the installation status of expect."
dpkg --get-selections | grep "^expect"
if [ $? -ne 0 ]; then
	echo -e "\033[1;44;37mInstalling expect...\033[0m\n"
	installExpect='apt install -y expect >/dev/null 2>&1'
	sudoExec $installExpect
fi

# First, check the existation of the gameInit.exp. If not, check eula.txt...

echo "_____________________________________________"
pwd
# Check if eual.txt exists.
if [ ! -f ./eula.txt ]; then
	# If not, create gameInit.exp to firstly launch mc, and this file will be created automatically.
	# RTFM to learn how to use expect wisely.
	cat > ./gameInit.exp<<EOF
#!/usr/bin/expect -f
set timeout 30
set maxmem [lindex $argv 0]
set minmem [lindex $argv 1]
set version [lindex $argv 2]
cd .
spawn java -Xmx${maxmem}M -Xms${minmem}M -jar minecraft_server.${version}.jar nogui
expect "*Stopping*" {exec sh -c {
touch finised
}}
EOF

    if [[ $? -eq 0 ]]; then
		chmod 700 ./gameInit.exp
		expect ./gameInit.exp ${maxmem} ${minmem} ${version}
		sed -i 's/eula=false/eula=true/g' ./eula.txt
		sed -i 's/online-mode=true/online-mode=false/g' ./server.properties
	fi
else
	# Else check whether the files have been modified.
	cat ./eula.txt | grep eula=true >/dev/null
	if [[ $? -eq 0 ]]; then
		echo "Detect that there you might have run minecraft_server.${version}.jar successfully."
	else
		echo "Modify eula.txt and server.properties now."
		sed -i 's/eula=false/eula=true/g' ./eula.txt
		sed -i 's/online-mode=true/online-mode=false/g' ./server.properties
		rm gameInit.exp
	fi
fi


cat > ./gameInit.exp<<EOF
#!/usr/bin/expect -f
set timeout 30
set maxmem [lindex $argv 0]
set minmem [lindex $argv 1]
set version [lindex $argv 2]
cd .
spawn java -Xmx${maxmem}M -Xms${minmem}M -jar minecraft_server.${version}.jar nogui
expect "*Done*" {
send "stop\r"
exec sh -c {
touch finised
}}
EOF
if [ $? -eq 0 ]; then
	chmod 700 ./gameInit.exp
	expect ./gameInit.exp ${maxmem} ${minmem} ${version}
fi
while [ ! $? ]
do
	sleep 1s
done
rm gameInit.exp finised