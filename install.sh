#!/bin/bash

HEADER='--header="User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Safari/537.36"'

# This function is used to check whether the input is numbers. Accept string arguments and replace numbers with regulars. Then check whether the ${tmp} is null.
checkInt(){
tmp=$(echo "$1"|sed 's/[0-9]//g')
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
    eval "$cmd"
    return $?
else
    eval "$1"
    return $?
fi
}

installPackage(){
if dpkg --get-selections | grep "^""$1" ; then
    echo -e "\033[1;44;37m${1} had been installed before.\033[0m\n"
else
    echo -e "\033[1;44;37mInstalling ${1}...\033[0m\n"
    sudoExec "apt install -y ${1} >/dev/null 2>&1"
fi
}

wrapExec(){
    ERROR=$( { eval $@ > outfile; } 2>&1 ) || { rm outfile; }
    echo "\033[1;46;33m${ERROR}\033[0m\n"
}

# Detecting sudo status.
if dpkg --get-selections | grep sudo ; then
    sudo_flag=true
else
    sudo_flag=false
fi

installPackage "curl"
installPackage "jq"
installPackage "expect"
installPackage "screen"

# deinstall ask for password?

# Detect ip address.
geoip=$(curl -s https://api.ip.sb/geoip)
CN=$(echo "$geoip"  |jq '.country_code == "CN"')
#CN=true

checkPackage='apt search openjdk-8-jdk-headless | grep openjdk-8-jdk-headless'

if ! sudoExec "${checkPackage}"; then
    apt_repo='apt install software-properties-common python-software-properties -y'
    sudoExec "${apt_repo}"
    sudoExec 'add-apt-repository ppa:openjdk-r/ppa -y'
    if ${CN}; then
        changePPA='sed -i "s/ppa.launchpad.net/launchpad.proxy.ustclug.org/g" /etc/apt/sources.list.d/openjdk-r-ubuntu-ppa-*.list'
        sudoExec "${changePPA}"
    fi
fi

echo 'Check installation status of java. Please note that this script will just check installation status of openjdk-8-jdk-headless.'

# Installing openjdk-8-jdk-headless.
sudoExec 'apt update'

if dpkg --get-selections | grep openjdk-8-jdk-headless; then
    echo -e "\033[1;44;37mPackage openjdk-8-jdk-headless have been installed.\033[0m\n"
else
    echo -e "\033[1;44;37mInstalling openjdk-8-jdk-headless... \033[0m"
    sudoExec 'apt install -y openjdk-8-jdk-headless'
    echo -e "\033[1;44;37mPackage openjdk-8-jdk-headless installed. \033[0m"
fi

# Installation Path
echo -n "Please speicify the path to install minecraft [default:${HOME}/minecraft)] :"
read -r installPath

if [ -z "${installPath}" ]; then
    installPath="${HOME}/minecraft"
fi

if echo "${installPath}" | grep 'minecraft/\?$'; then
    installPath=$( echo "${installPath%/minecraf*}")
fi

if [ ! -d "${installPath}"/minecraft ]; then
    echo "Create minecraft directory."
    mkdir -p "${installPath}"/minecraft
fi

cd "${installPath}"/minecraft || return 255
if [ $? = 255 ]; then echo "No such Directory!"; exit; fi

# Set a flag to detect whether to download a new minecraft server.
if [ -f ./minecraft_server.*.jar ]; then
    tempver=$(find ./minecraft_server.*.jar | grep -o -P "(?<=server\.)[0-9]+\.[0-9]+\.*[0-9]*(?=\.jar)")
    # Store the existed minecraft server version in tempver.
    while true; do
        echo -n "Detect that there exists \"minecraft_server.${tempver}.jar\", do you want to get a new one? [yes/NO] :"
        read -r yn
        if [ -z "${yn}" ]; then
            yn='N'
        fi
        case $yn in
            [Yy]* )
                wrapExec rm minecraft_server."${tempver}".jar
                wrapExec rm server.properties
                wrapExec rm eula.txt
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

# Download version_manifest.json
if [ ! -f "version_manifest.json" ]; then
    echo "Downloading version_manifest.json ..."
    wget "${HEADER}" -O "${installPath}"/minecraft/version_manifest.json "https://launchermeta.mojang.com/mc/game/version_manifest.json"
fi

# flag -eq 1: No existing server file.
if [ ${flag} -eq 1 ]; then

    while true; do
        echo -n "Do you want to show you all the available stable versions? [yes/NO]"
        read -r yn
        if [ -z "${yn}" ]; then
            yn='N'
        fi
        case $yn in
            [Yy]* )
                cat version_manifest.json | jq ".versions[].id" | grep -o -P "(?<=\")[0-9]+\.[0-9]+\.*[0-9]*(?=\")"
                break
                ;;
            [Nn]* )
                echo -e "\033[1;44;37mYou can find the stable version numbers here. https://minecraft.gamepedia.com/Java_Edition_version_history/Development_versions\033[0m\n"
                break
                ;;
            * ) echo "Please answer yes or no.";;
        esac
    done

    echo -n "Chose the version you want to use: [default=1.12.2] "
    read -r version
    if [ -z "${version}" ];then
        version='1.12.2'
    fi
    if ${CN}; then
        while true; do
            echo -n "Use IPv6 to download:[yes/NO] "
            read -r yn
            if [ -z "${yn}" ]; then
                yn='N'
            fi
            case $yn in
                [Yy]* )
                    IPv6="-6"
                    break
                    ;;
                [Nn]* )
                    IPv6="-4"
                    break
                    ;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi

    # MCLanucher API reference: https://github.com/tomsik68/mclauncher-api
    # Query
    version_url=$(cat "${installPath}"/minecraft/version_manifest.json | jq -r --arg "VERSION" "${version}" '.versions[] | select(.id == $VERSION) | .url')
    echo "Downloading ${version}.json"
    wget "${HEADER}" -O "${installPath}/minecraft/${version}.json" "${version_url}"
    # Network Error?
    server_url=$(cat "${installPath}"/minecraft/${version}.json | jq -r '.downloads.server.url')
    echo "Downloading minecraft_server.${version}.jar"
    if ${CN} ;then
        server_url=$(echo "$server_url" | sed "s/launcher.mojang.com/mirrors.limee.dev/g")
        wget ${IPv6} "${HEADER}" -O "${installPath}/minecraft/minecraft_server.${version}.jar" "${server_url}"
    else
        wget ${IPv6} "${HEADER}" -O "${installPath}/minecraft/minecraft_server.${version}.jar" "${server_url}"
    fi
fi


while true
do
    # Use Ctrl + Backspace to delete error input.
    read -p "Set the minimum memory and maximum memory. [example: 512 1024]: " minmem maxmem
    if [ -z "${maxmem}" ]; then
        check=0
    elif [ -z "${minmem}" ]; then
        check=0
    else
        check=1
    fi
    checkInt "${maxmem}"
    maxS=$?
    checkInt "${minmem}"
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

# First, check the existion of the gameInit.exp. If not, check eula.txt...

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
set installPath [lindex $argv 3]

spawn java -Xmx${maxmem}M -Xms${minmem}M -jar ${installPath}/minecraft/minecraft_server.${version}.jar nogui
expect "*Stopping*" {exec sh -c {
touch finished
}}
EOF

    if [[ $? -eq 0 ]]; then
        chmod +x ./gameInit.exp
        expect ./gameInit.exp "${maxmem}" "${minmem}" ${version} "${installPath}"
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
        wrapExec rm gameInit.exp
    fi
fi

screen java -Xmx"${maxmem}"M -Xms"${minmem}"M -jar "${installPath}"/minecraft/minecraft_server.${version}.jar nogui

