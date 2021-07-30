#!/bin/bash

showHelp() {
# `cat << EOF` This means that cat should stop reading when EOF is detected
cat << EOF  
Usage: ./edge-config -c <connection-string> -e  <edge-version> [-h]

  -h  Display help
  -c  <connection-string>       Sets the given connectionstring
  -e  <edge-version>            1.1 or 1.2
EOF
# EOF is found above and hence cat command stops reading. This is equivalent to echo but much neater when printing out.
}

# https://stackoverflow.com/questions/16483119/an-example-of-how-to-use-getopts-in-bash

while getopts "hc:e:" args; do
    case "${args}" in
        h ) showHelp;;
        c ) connString="${OPTARG}";;
        e ) edgeVersion="${OPTARG}";;
        \? ) echo "Unknown option: -$OPTARG" >&2; exit 1;;
        :  ) echo "Missing option argument for -$OPTARG" >&2; exit 1;;
        *  ) echo "Unimplemented option: -$OPTARG" >&2; exit 1;;
    esac
done
shift $((OPTIND-1))

if [ ! "$connString" ] || [ ! "$edgeVersion" ];
then
    showHelp
    exit 1
fi

if [ "$edgeVersion" = "1.2" ];
then
    echo conn-string="$connString"
    sudo iotedge config mp --force --connection-string ${connString}
    sudo iotedge config apply -c '/etc/aziot/config.toml'
    exit 0
fi

if [ "$edgeVersion" = "1.1" ];
then
    export key="device_connection_string"
    sudo sed -i "s#\(${key}: \).*#\1\"$connString\"#g" /etc/iotedge/config.yaml
    sudo systemctl restart iotedge 
    exit 0
fi