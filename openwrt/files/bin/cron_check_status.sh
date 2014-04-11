#!/bin/sh 

. /lib/functions.sh


get_status_from_server()
{
    local sn
    local status_code
    local response

    config_get sn $1 sn
    response=`/usr/bin/curl -k --connect-timeout 20 -s -d "sn=$sn&do=status" https://ss-login.hideus.net/`
    status_code=$(echo $response | awk -F '|' '{print $1}')

    if [ $status_code == 'OK' ]; then
        local registertime=$(echo $response | awk -F '|' '{print $2}')
        local billingtime=$(echo $response | awk -F '|' '{print $3}')
        local expiredtime=$(echo $response | awk -F '|' '{print $4}')
        local expired=$(echo $response | awk -F '|' '{print $5}')
        local traffic$(echo $response | awk -F '|' '{print $6}')

        # save config
        uci set superspeed.userinfo.registertime="$registertime"
        uci set superspeed.userinfo.billingtime="$billingtime"
        uci set superspeed.userinfo.expiredtime="$expiredtime"
        uci set superspeed.userinfo.expired="$expired"
        uci set superspeed.userinfo.traffic="$traffic"
        uci commit superspeed
    fi

}

check_running()
{
    # first check network
    check_network
    network_status=$(uci get superspeed.userinfo.network_status)
    if [ $network_status == "0" ]; then
        exit 1
    fi

    # check sn
    local sn=$(uci get superspeed.userinfo.sn)
    if [ ! -n "$sn" ]; then
        exit 1
    fi

    local enable=$(uci get superspeed.userinfo.enable)
    # if enable
    if [ $enable == "1" ]; then
        logger -t cron_root -s "superspeed enabled, check service running status" > /dev/null 2>&1
        # if tmp pid file exist
        if [ -f /tmp/ss-redir.pid ]; then
            local pid_file=$(cat /tmp/ss-redir.pid)
            local run_pid
            ps > /tmp/ps
            run_pid=$(cat /tmp/ps |grep ss-redir | awk '{print $1}')
            if [ "$run_pid" != "$pid_file" ]; then
                # restart superspeed
                /etc/init.d/superspeed restart
            else
                logger -t cron_root -s "service running ok, continue" > /dev/null 2>&1
                check_alive
            fi
        # if tmp file not exist
        else
            # service not start
            /etc/init.d/superspeed start
        fi
    fi
}

check_network()
{
    local network_status
    network_status=$(/usr/bin/curl -k --connect-timeout 10 -s https://ss-login.hideus.net/check_network.php)
    if [ "$network_status" == "OK" ]; then
        uci set superspeed.userinfo.network_status=1
    else
        uci set superspeed.userinfo.network_status=0
    fi
}

check_alive()
{
    local alive
    alive=$(/usr/bin/curl -k --connect-timeout 10 -s https://ss-login.hideus.net/check_alive.php)
    if [ "$alive" != "OK" ]; then
        # try again
        alive=$(/usr/bin/curl -k --connect-timeout 10 -s https://ss-login.hideus.net/check_alive.php)
        if [ "$alive" != "OK" ]; then
            # maybe server down
            logger -t cron_root -s "server maybe down,so we restart the service" > /dev/null 2>&1
            /etc/init.d/superspeed restart
        fi
    fi
}

update_service()
{
    local sn=$(uci get superspeed.userinfo.sn)
    # if no sn
    if [ ! -n "$sn" ]; then
        exit 1
    fi
    mkdir -p /etc/superspeed
    /usr/bin/curl -k --connect-timeout 10 -s https://ss-login.hideus.net/update_service.php?sn=$sn > /etc/superspeed/speedtype.conf

}

usage() {
    cat <<EOF
Usage: $0 [get_status|check_running|check_alive|update_service]
EOF
    exit 1
}

if [ $# == "0" ]; then
    usage
    exit 1
fi

if [ $1 == "get_status" ]; then
    config_load superspeed
    config_foreach get_status_from_server main
elif [ $1 ==  "check_running" ]; then
    check_running
elif [ $1 == "update_service" ];then
    update_service
fi

