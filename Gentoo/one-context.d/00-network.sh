#!/bin/bash

# Gets IP address from a given MAC
mac2ip() {
    mac=$1

    let ip_a=0x`echo $mac | cut -d: -f 3`
    let ip_b=0x`echo $mac | cut -d: -f 4`
    let ip_c=0x`echo $mac | cut -d: -f 5`
    let ip_d=0x`echo $mac | cut -d: -f 6`

    ip="$ip_a.$ip_b.$ip_c.$ip_d"

    echo $ip
}

# Gets the network part of an IP
get_network() {
    network=$(get_iface_var "NETWORK")

    if [ -z "$network" ]; then
        network="$(echo $IP | cut -d'.' -f1,2,3).0"
    fi

    echo $network
}

# Gets the network mask
get_mask() {
    mask=$(get_iface_var "MASK")

    if [ -z "$mask" ]; then
        mask="255.255.255.0"
    fi

    echo $mask
}

is_gateway() {
    if [ -z "$GATEWAY_IFACE_NUM" ]; then
        true
    else
        [ "$IFACE_NUM" = "$GATEWAY_IFACE_NUM" ]
    fi
}

# Gets the network gateway
get_gateway() {
    if is_gateway; then
        gateway=$(get_iface_var "GATEWAY")

        if [ -z "$gateway" ]; then
            if [ "$DEV" = "eth0" ]; then
                net_prefix=$(echo $NETWORK | cut -d'.' -f1,2,3)
                gateway="${net_prefix}.1"
            fi
        fi

        echo $gateway
    fi
}

# Gets the network gateway6
get_gateway6() {
    if is_gateway; then
        get_iface_var "GATEWAY6"
    fi
}

get_ip() {
    ip=$(get_iface_var "IP")

    if [ -z "$ip" ]; then
        ip=$(mac2ip $MAC)
    fi

    echo $ip
}

get_iface_var() {
    var_name="${UPCASE_DEV}_$1"
    var=$(eval "echo \"\${$var_name}\"")

    echo $var
}

gen_iface_conf() {
    cat <<EOT
config_$DEV="$IP netmask $MASK"
EOT

    if [ -n "$GATEWAY" ]; then
        echo "routes_$DEV=\"default via $GATEWAY\""
    fi

    echo ""
}

gen_iface6_conf() {
    cat <<EOT
IPV6INIT=yes
IPV6ADDR=$IPV6
EOT

    if [ -n "$GATEWAY6" ]; then
        echo "IPV6_DEFAULTGW=$GATEWAY6"
    fi

    echo ""
}

get_interface_mac()
{
    ip link show | awk '/^[0-9]+: [[:alnum:]]+:/ { device=$2; gsub(/:/, "",device)} /link\/ether/ { print device " " $2 }'
}

get_context_interfaces()
{
    env | grep -E "^ETH[0-9]+_MAC=" | sed 's/_.*$//' | sort
}

get_dev()
{
    list="$1"
    mac="$2"

    echo "$list" | grep "$mac" | cut -d' ' -f1 | tail -n1
}

gen_network_configuration()
{
    INTERFACE_MAC=$(get_interface_mac)
    CONTEXT_INTERFACES=$(get_context_interfaces)
    GATEWAY_IFACE_NUM=$(echo "$GATEWAY_IFACE" | sed 's/^ETH//')

    for interface in $CONTEXT_INTERFACES; do
        UPCASE_DEV=$interface
        MAC=$(get_iface_var "MAC")
        DEV=$(get_dev "$INTERFACE_MAC" "$MAC")
        IFACE_NUM=$(echo "$UPCASE_DEV" | sed 's/^ETH//')

        IP=$(get_ip)
        NETWORK=$(get_network)
        MASK=$(get_mask)
        GATEWAY=$(get_gateway)

        IPV6=$(get_iface_var "IPV6")
        [[ -z $IPV6 ]] && IPV6=$(get_iface_var "IP6")
        GATEWAY6=$(get_gateway6)
        CONTEXT_FORCE_IPV4=$(get_iface_var "CONTEXT_FORCE_IPV4")

        (
            cat <<EOT
modules="iproute2"
dns_servers_$DEV="$GATEWAY"
EOT
            [[ -z $IPV6 || -n $CONTEXT_FORCE_IPV4 ]] && gen_iface_conf
            [[ -n $IPV6 ]] && gen_iface6_conf

        ) > /etc/conf.d/net

        # /etc/init.d/net.$DEV restart 

    done
}

configure_network()
{
    gen_network_configuration

    /etc/init.d/net.$DEV restart
    ip r add default via $GATEWAY

    sleep 2
}

configure_network