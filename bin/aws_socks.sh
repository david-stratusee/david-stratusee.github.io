#!/bin/bash -
#===============================================================================
#          FILE: new_socks.sh
#         USAGE: ./new_socks.sh
#   DESCRIPTION:
#        AUTHOR: dengwei
#       CREATED: 2015/01/05 21:18
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error

#-------------------------------------------------------------------------------
# config here
# 1. modify username
# 2. add proxy.pac to /Library/WebServer/Documents/proxy.pac
#-------------------------------------------------------------------------------
username=david

available_host_port=("dev-aie.stratusee.com:22" "dev-aie3.stratusee.com:22" "us.stratusee.com:2221")
host_port=${available_host_port[0]}

ETH="Wi-Fi"
#-------------------------------------------------------------------------------
# config end
#-------------------------------------------------------------------------------

function show_proxy()
{
    echo ===========================
    echo "pac_proxy state:"
    networksetup -getautoproxyurl ${ETH}
    echo ===========================
    ps -ef | grep -v grep | egrep --color=auto "(ssh -D|CMD|watch_socks|httpd)"
    echo ===========================
    if [ -f /tmp/watch_socks.log ]; then
        echo "/tmp/watch_socks.log:"
        cat /tmp/watch_socks.log
        echo ===========================
    fi
}

function fill_and_run_proxy()
{
    remote_host=`echo ${host_port} | awk -F":" '{print $1}'`
    remote_port=`echo ${host_port} | awk -F":" '{print $2}'`

    ${HOME}/bin/watch_socks.sh ${username} ${remote_host} ${remote_port} >>/tmp/watch_socks.log 2>&1 &
}

function kill_process()
{
    pidc=`ps -ef | grep -v grep | grep -c "$@"`
    if [ $pidc -gt 0 ]; then
        sshpid=`ps -ef | grep "$@" | grep -v grep | awk '{print $2}'`
        echo "kill $@, pid: ${sshpid}"
        kill $sshpid
    fi
}

function print_avail_host()
{
    nhost=0
    echo "available socks host:port is:[${#available_host_port[*]}]"
    for node in ${available_host_port[*]}; do
        if [ "${host_port}" == "${node}" ]; then
            echo " [${nhost}] $node [***]"
        else
            echo " [${nhost}] $node"
        fi

        nhost=`expr ${nhost} + 1`
    done
}

function check_host_port()
{
    check_value=$1
    for node in ${available_host_port[*]}; do
        if [ "${check_value}" == "${node}" ]; then
            return 0
        fi
    done

    return 1
}

function update_pac()
{
    has_wget=$1
    if [ $has_wget -eq 0 ]; then
        rm -f /tmp/proxy.pac
        wget --no-check-certificate -nv https://david-stratusee.github.io/proxy.pac -P /tmp/
        if [ $? -eq 0 ]; then
            sudo mv /tmp/proxy.pac ${local_proxydir}/
            echo proxy.pac is in ${local_proxydir}
        elif [ ! -f ${local_proxydir}/proxy.pac ]; then
            echo "can not get proxy.pac, exit..."
            return 1
        else
            echo "can not get proxy.pac from github, so just use old one"
        fi
    fi

    return 0
}

function aws_socks_help()
{
    echo "------------------------------------"
    echo "Help Usage: "
    echo "-c for clear socks proxy"
    echo "-l for query socks proxy"
    echo "-f for local file for pac, only for Safari"
    echo "-i ip for set socks proxy and http proxy"
    echo "-p to set socks proxy's host_port, format: proxy:port"
    print_avail_host
    echo "no args for set socks proxy and DIRECT"
    echo "------------------------------------"
}

IP=""
MODE="normal"
restart=0
use_local_web=1
while getopts 'e:p:i:hcrlf' opt; do
    case $opt in
        e) 
            ETH=$OPTARG
            ;;
        i)  
            IP=$OPTARG
            ping -q -c 1 ${IP} >/dev/null
            if [ $? -ne 0 ]; then
                echo "${IP} is unreachable"
                exit 1
            fi
            ;;
        f)
            use_local_web=0
            ;;
        c|r)
            if [ "${MODE}" == "normal" ]; then
                MODE="clear"
                if [ "$opt" == 'r' ]; then
                    restart=1
                fi
            else
                echo "clear and query mode should not be used at same time"
                aws_socks_help
                exit 1
            fi
            ;;
        l)
            if [ "${MODE}" == "normal" ]; then
                MODE="query"
            else
                echo "clear and query mode should not be used at same time"
                aws_socks_help
                exit 1
            fi
            ;;
        p)
            isdigit=`echo $OPTARG | grep -c "^[0-9]$"`
            if [ $isdigit -gt 0 ] && [ $OPTARG -lt ${#available_host_port[*]} ]; then
                host_port=${available_host_port[$OPTARG]}
            else
                check_host_port $OPTARG
                if [ $? -eq 0 ]; then
                    host_port=$OPTARG
                else
                    echo "invalid host_port format"
                    aws_socks_help
                    exit 1
                fi
            fi
            ;;
        h|*)
            aws_socks_help
            exit 0
    esac
done

if [ ${use_local_web} -gt 0 ]; then
    local_proxydir="/Library/WebServer/Documents/"
else
    local_proxydir="/Applications/Safari.app/Contents/Resources"
fi

if [ "${MODE}" == "clear" ]; then
    kill_process "watch_socks"
    kill_process "ssh -D"

    httpd_count=`ps -ef | grep -v grep | grep -c httpd`
    if [ ${httpd_count} -gt 0 ]; then
        sudo apachectl graceful-stop
    fi
    sudo networksetup -setautoproxystate ${ETH} off

    if [ ${restart} -gt 0 ]; then
        MODE="normal"
    fi
fi

if [ "${MODE}" == "normal" ]; then
    which wget >/dev/null
    has_wget=$?

    sudo networksetup -setautoproxystate ${ETH} off
    if [ "${IP}" == "" ]; then
        update_pac $has_wget
        if [ $? -ne 0 ]; then
            exit 1
        fi

        if [ ! -f ${local_proxydir}/proxy.pac ]; then
            sudo networksetup -setautoproxyurl ${ETH} "https://david-stratusee.github.io/proxy.pac"
        else
            if [ ${use_local_web} -gt 0 ]; then
                sudo apachectl start
                sudo networksetup -setautoproxyurl ${ETH} "http://127.0.0.1/proxy.pac"
            else
                sudo networksetup -setautoproxyurl ${ETH} "file://localhost${local_proxydir}/proxy.pac"
            fi
        fi
    else
        update_pac $has_wget
        if [ $? -ne 0 ]; then
            exit 1
        fi

        sudo cp -f ${local_proxydir}/proxy.pac ${local_proxydir}/proxy_aie.pac
        sudo sed -i "" -e "s/'DIRECT'/'PROXY ${IP}:3128'/g" ${local_proxydir}/proxy_aie.pac
        if [ ${use_local_web} -gt 0 ]; then
            sudo apachectl start
            sudo networksetup -setautoproxyurl ${ETH} "http://127.0.0.1/proxy_aie.pac"
        else
            sudo networksetup -setautoproxyurl ${ETH} "file://localhost${local_proxydir}/proxy_aie.pac"
        fi
    fi

    fill_and_run_proxy
    sudo networksetup -setautoproxystate ${ETH} on
fi
show_proxy

