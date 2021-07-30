!/bin/bash

showHelp() {
# `cat << EOF` This means that cat should stop reading when EOF is detected
cat << EOF  
Usage: ./edge-install -e <edge-version> [-h]

  -h  Display help
  -e  <edge-version>            1.1, 1.2 or 1.2.2
EOF
# EOF is found above and hence cat command stops reading. This is equivalent to echo but much neater when printing out.
}

while getopts "hc:e:" args; do
    case "${args}" in
        h ) showHelp;;
        e ) edgeVersion="${OPTARG}";;
        \? ) echo "Unknown option: -$OPTARG" >&2; exit 1;;
        :  ) echo "Missing option argument for -$OPTARG" >&2; exit 1;;
        *  ) echo "Unimplemented option: -$OPTARG" >&2; exit 1;;
    esac
done
shift $((OPTIND-1))

if [ ! "$edgeVersion" ];
then
    showHelp
    exit 1
fi

curl https://packages.microsoft.com/config/ubuntu/18.04/multiarch/prod.list > ./microsoft-prod.list
sudo cp ./microsoft-prod.list /etc/apt/sources.list.d/
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
sudo cp ./microsoft.gpg /etc/apt/trusted.gpg.d/
sudo apt-get update
sudo apt-get install moby-engine -y

if [ "$edgeVersion" = "1.2.2" ]; then
    echo installing iot edge 1.2.2
    sudo apt-get install aziot-identity-service=1.2.1-1
    sudo apt-get install aziot-edge=1.2.2-1 -y
    exit 0
fi

if [ "$edgeVersion" = "1.2" ]; then
    echo installing latest iot edge 1.2.x
    sudo apt-get install aziot-edge -y
    exit 0
fi

if [ "$edgeVersion" = "1.1" ]; then
    echo installing latest iot edge 1.1.x
    sudo apt-get install iotedge
    exit 0
fi

echo ERROR: missing/unknown argument "$1". Expected values: 1.2.2, 1.2, 1.1
exit 1