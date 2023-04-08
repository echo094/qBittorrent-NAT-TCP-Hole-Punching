#!/bin/sh

# Natter/NATMap
tool_type="NATMap"
# qBittorrent/transmission
downloader_type="qBittorrent"
host="localhost"
web_port="8080"
username="admin"
password="adminadmin"

if [[ "$tool_type" == "NATMap" ]]; then
public_ip=$1
public_port=$2
private_port=$4
protocol=$5
else
protocol=$1
private_port=$3
public_ip=$4
public_port=$5
fi
echo "Mapping $protocol://$public_ip:$public_port -> $private_port"

if [[ "$downloader_type" == "transmission" ]]; then
echo "Update transmission listen port to $public_port..."
# Update transmission listen port.
tr_session=$(curl --silent -u "$username:$password" "http://$host:$web_port/transmission/web" | grep --regexp="X-Transmission-Session-Id: [0-9a-zA-Z]*" -o)
echo $(curl --silent "http://$host:$web_port/transmission/rpc" -u "$username:$password" -H "${tr_session}" --data-raw '{"method":"session-set","arguments":{"peer-port":'$public_port',"_easyui_textbox_input59":'$public_port'},"tag":""}')
echo $(curl --silent "http://$host:$web_port/transmission/rpc" -u "$username:$password" -H "${tr_session}" --data-raw '{"method":"session-get","arguments":{"fields": ["peer-port"]},"tag":""}')
else
echo "Update qBittorrent listen port to $public_port..."
# Update qBittorrent listen port.
qb_cookie=$(curl -s -i --header "Referer: http://$host:$web_port" --data "username=$username&password=$password" http://$host:$web_port/api/v2/auth/login | grep -i set-cookie | cut -c13-48)
curl -X POST -b "$qb_cookie" -d 'json={"listen_port":"'$public_port'"}' "http://$host:$web_port/api/v2/app/setPreferences"
fi

echo "Update iptables..."

# Use iptables to forward traffic.
LINE_NUMBER=$(iptables -t nat -nvL --line-number | grep ${private_port} | head -n 1 | grep -o '^[0-9]+')
iptables -t nat -D PREROUTING $LINE_NUMBER
iptables -t nat -I PREROUTING -p tcp --dport $private_port -j REDIRECT --to-port $public_port

echo "Done."