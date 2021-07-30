#!/bin/bash
showHelp() {
# `cat << EOF` This means that cat should stop reading when EOF is detected
cat << EOF  
Usage: ./vm-iotedge-provision.sh [-h] -s <vm-size> -g  <resource-group> -e <iot-edge-version> -h <iot-hub-name> [-d <deployment-manifest>] [-l] [-k <ssh-keys-folder>]

  -h                            display this help
  -s  <vm-size>                 vm size ('Standard_DS2_v2', 'Standard_D2_v2', 'Standard_DS2_v2'...)
  -g  <resource-group>          resource-group
  -e  <iot-edge-version>        '1.1', '1.2' or '1.2.2'
  -n  <iot-hub-name>            IoT HUB name (will be used to provision the IoT Edge)
  -d  <deployment-manifest>     (optional) deployment manifest. 
                                Default is none.
  -u  <username>                (optional) VM username.
                                Default is 'arlotito'
  -k  <ssh-keys-folder>         (optional) folder with ssh key pair ('vm', 'vm.pub'). If empty, a key pair will be generareted.
                                Default is './keys' 
  -l                            (optional) SSH into the VM once done.
                                Default is do not login.

Prerequisites:
    - ssh client
    - az cli with iot extension (https://github.com/Azure/azure-iot-cli-extension)
    - az cli signed-in onto the tenant/subscription where you want to operate. If not already signed-in, do:
        az login

Example:

    ./vm-iotedge-provision.sh -s Standard_DS2_v2 -g edge-benchmark-vm-rg -d ../config/empty-1.2.json -e 1.2 -n my-iot-hub

EOF
# EOF is found above and hence cat command stops reading. This is equivalent to echo but much neater when printing out.
}

# https://stackoverflow.com/questions/16483119/an-example-of-how-to-use-getopts-in-bash
login="false";
deploymentManifest=""
HUB_NAME=""
SSH_KEY_FOLDER="./keys"
HOST_USERNAME="arlotito"
while getopts "hls:d:g:e:k:n:u:" args; do
    case "${args}" in
        h ) showHelp;;
        s ) vmSize="${OPTARG}";;
        d ) deploymentManifest="${OPTARG}";;
        g ) rg="${OPTARG}";;
        e ) edgeVersion="${OPTARG}";;
        n ) HUB_NAME="${OPTARG}";;
        k ) SSH_KEY_FOLDER="${OPTARG}";;
        u ) HOST_USERNAME="${OPTARG}";;
        l ) login="true";;
        \? ) echo "Unknown option: -$OPTARG" >&2; echo; showHelp; exit 1;;
        :  ) echo "Missing option argument for -$OPTARG" >&2; echo; showHelp; exit 1;;
        *  ) echo "Unimplemented option: -$OPTARG" >&2; echo; showHelp; exit 1;;
    esac
done
shift $((OPTIND-1))

if [ ! "$vmSize" ] || [ ! "$rg" ] || [ ! "$edgeVersion" ] || [ ! "$HUB_NAME" ];
then
    echo "ERROR: required parameter is missing"
    echo
    showHelp
    exit 1
fi

export TODAY=$(date +"%s")
export VM_NAME=${vmSize}-edge-$edgeVersion-$TODAY 
# replace "_" with "-"
export VM_NAME=${VM_NAME//_/-}
# replace "." with "-"
export VM_NAME=${VM_NAME//./-}
# convert the string to lowercase
export VM_NAME=${VM_NAME,,}             
    

export VM_RG=${rg}

export SSH_KEY_PUB="$SSH_KEY_FOLDER/vm.pub"
export SSH_KEY_PRIVATE="$SSH_KEY_FOLDER/vm"

export DEVICE_NAME=$VM_NAME

export DEVICE_TAG=TEST

##
# az login
# az account list -o tsv
# az account set --subscription internal_sub_arturo

# create ssh keys if not already there
if [ ! -f "$SSH_KEY_PUB" ] || [ ! -f "$SSH_KEY_PRIVATE" ]; then
    echo "creating SSH keypair..."
    mkdir -p $SSH_KEY_FOLDER
    ssh-keygen -b 2048 -t rsa -f $SSH_KEY_PRIVATE -q -N ""
    chmod 400 $SSH_KEY_PRIVATE
    chmod 444 $SSH_KEY_PUB
fi

#HUB
# az group create --location westeurope -g $HUB_RG
# az iot hub create -n ${HUB_NAME} -g ${HUB_RG} --sku S1 --unit 10

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo creating resource group...
result=$(az group create --location westeurope --resource-group edge-benchmark-vm-rg | jq -r .properties.provisioningState)
if [ "$result" != "Succeeded" ]; then
    echo -e "${RED}ERROR!${NC}"
    exit 1
fi

# create VM
echo creating vm...
result=$(az vm create --name $VM_NAME -g $VM_RG \
    --public-ip-address-dns-name $VM_NAME --public-ip-sku Standard \
    --image Canonical:UbuntuServer:18.04-LTS:latest \
    --size $vmSize \
    --admin-username $HOST_USERNAME \
    --ssh-key-values $SSH_KEY_PUB \
    | jq -r .fqdns
)
if [ "$result" == "" ]; then
    echo -e "${RED}ERROR!${NC}"
    exit 1
fi

export HOST_IP=$result

echo "setting vm autoshutdown..."
result=$(az vm auto-shutdown \
    --name $VM_NAME -g $VM_RG \
    --time 2100 | jq -r .id
)
if [ "$result" == "" ]; then
    echo -e "${RED}ERROR!${NC}"
    exit 1
fi

# register iot edge identity
echo "register device identity with IoT HUB..."
result=$(az iot hub device-identity create \
    -n $HUB_NAME \
    -d $DEVICE_NAME \
    --ee | jq -r .status
)
if [ "$result" != "enabled" ]; then
    echo -e "${RED}ERROR!${NC}"
    exit 1
fi

echo "getting the connection string..."
result=$(az iot hub device-identity connection-string show \
    -n $HUB_NAME \
    -d $DEVICE_NAME | jq -r .connectionString)
if [ "$result" == "" ]; then
    echo -e "${RED}ERROR!${NC}"
    exit 1
fi

export CONN_STRING=$result

# wait a bit 
echo "wait 10s..."
sleep 10

# add the host's key to the known-host (to avoid the prompt later on)
echo "adding HOST's pub key to known hosts..."
ssh-keyscan -t ssh-rsa $HOST_IP >> ~/.ssh/known_hosts

# add a TAG
#az iot hub module-twin update \
#    -n $HUB_NAME  \
#    -d $DEVICE_NAME \
#    --tags "{\"benchmark\": \"${DEVICE_TAG}\"}"

# provision iot edge
echo "installing iot edge..."
result=$(ssh $HOST_USERNAME@$HOST_IP -i $SSH_KEY_PRIVATE -t "bash -s" -- < edge-install.sh -e "${edgeVersion}" 1>null 2>null )

echo "configuring iot edge..."
result=$(ssh $HOST_USERNAME@$HOST_IP -i $SSH_KEY_PRIVATE -t "bash -s" -- <  ./edge-config.sh -e "${edgeVersion}" -c ${CONN_STRING@Q} 1>null 2>null )

if [ "$deploymentManifest" != "" ]; then
    # deploy
    echo "deploying manifest $deploymentManifest..."
    az iot edge set-modules \
        -n $HUB_NAME \
        -d $DEVICE_NAME \
        --content $deploymentManifest
fi

# wait a bit 
echo "wait 10s..."
sleep 10

echo "done!"
echo
echo

echo "checking whether IoT Edge is up and running on the VM:"
ssh $HOST_USERNAME@$HOST_IP -i $SSH_KEY_PRIVATE -t "iotedge version"
ssh $HOST_USERNAME@$HOST_IP -i $SSH_KEY_PRIVATE -t "iotedge list"

# print info
echo
echo
echo "SUMMARY"
echo "----------------------------------------"
echo "VM"
echo "  - name:         $VM_NAME"
echo "  - rg:           $VM_RG"
echo "  - fqdn:         $HOST_IP"
echo "  - username:     $HOST_USERNAME"
echo "  - ssh keys:     $SSH_KEY_PUB, $SSH_KEY_PRIVATE"
echo ""
echo "IoT HUB"
echo "  - name:         $HUB_NAME"
echo "  - device ID:    $DEVICE_NAME"
echo "  - conn string:  $CONN_STRING"
echo
echo "to connect to the VM:"
echo "  ssh $HOST_USERNAME@$HOST_IP -i $SSH_KEY_PRIVATE"

if [ "$login" = "true" ]; then
    echo "login into machine..."
    ssh $HOST_USERNAME@$HOST_IP -i $SSH_KEY_PRIVATE
fi

exit 0