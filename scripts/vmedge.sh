#!/bin/bash
showHelp() {
# `cat << EOF` This means that cat should stop reading when EOF is detected
cat << EOF  
Usage: ./vm-iotedge-provision.sh [-h] -s <vm-size> -g  <resource-group> -e <iot-edge-version> [-h <iot-hub-name>] [-d <deployment-manifest>] [-l] [-k <ssh-keys-folder>]

  -h                            (optional) display this help
  -s  <vm-size>                 vm size ('Standard_DS2_v2', 'Standard_D2_v2', 'Standard_DS2_v2'...)
  -g  <resource-group>          resource-group
  -e  <iot-edge-version>        (optional) '1.1', '1.2' or '1.2.2'. If not specified, iot edge won't be installed
  -n  <iot-hub-name>            (optional) IoT HUB name (will be used to provision the IoT Edge)
                                If not specified, iot edge won't be provisioned. 
  -d  <deployment-manifest>     (optional) deployment manifest. 
                                Default is none.
  -u  <username>                (optional) VM username.
                                Default is 'azuser'
  -k  <ssh-keys-folder>         (optional) folder with ssh key pair ('vmedge.key', 'vmedge.pub'). If non existing already, a key pair will be generareted.
                                Default folder is '~/.ssh' 
  -l                            (optional) SSH into the VM once done.
                                Default is do not login.

Example, deploy VM only:
    ./vm-iotedge-provision.sh -s Standard_DS2_v2 -g edge-benchmark-vm-rg 

Example, deploy VM and install iot edge (but do not provision it):
    ./vm-iotedge-provision.sh -s Standard_DS2_v2 -g edge-benchmark-vm-rg -e 1.2

Example, deploy VM and install iot edge, provision an identity on iot hub and configure iot edge accordingly:
    ./vm-iotedge-provision.sh -s Standard_DS2_v2 -g edge-benchmark-vm-rg -e 1.2 -n my-iot-hub

Example, deploy VM and install iot edge, provision an identity on iot hub, configure iot edge accordingly and deploy a manifest:
    ./vm-iotedge-provision.sh -s Standard_DS2_v2 -g edge-benchmark-vm-rg -e 1.2 -n my-iot-hub -d ./manifests/empty-1.2.json

Prerequisites:
    - ssh client
    - jq (install with: sudo apt-get install jq -y)
    - az cli with iot extension (https://github.com/Azure/azure-iot-cli-extension)

Note:
If not already signed-in, do 'az login' and select the tenant/subscription where you want to operate.

EOF
# EOF is found above and hence cat command stops reading. This is equivalent to echo but much neater when printing out.
}

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# https://stackoverflow.com/questions/16483119/an-example-of-how-to-use-getopts-in-bash
login="false";
deploymentManifest=""
HUB_NAME=""
SSH_KEY_FOLDER="${HOME}/.ssh"
HOST_USERNAME="azuser"
VM_SHUTDOWN_TIME=2100
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

if [ ! "$vmSize" ] || [ ! "$rg" ];
then
    echo -e "${RED}ERROR: required parameter is missing${NC}"
    echo "Please see help: ./vm-iotedge-provision.sh -h"
    exit 1
fi

if [ "$edgeVersion" ];
then
    if [ "$edgeVersion" != "1.1" ] && [ "$edgeVersion" != "1.2" ] && [ "$edgeVersion" != "1.2.2" ];
    then
        echo -e "${RED}ERROR: tag '$edgeVersion' is not supported${NC}"
        echo "Please see help: ./vm-iotedge-provision.sh -h"
        exit 1
    fi
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

export SSH_KEY_NAME="vmedge"
export SSH_KEY_PUB=$SSH_KEY_FOLDER/$SSH_KEY_NAME.pub
export SSH_KEY_PRIVATE=$SSH_KEY_FOLDER/$SSH_KEY_NAME.key

export DEVICE_NAME=$VM_NAME


export EDGE_CONFIG_SCRIPT_URL="https://raw.githubusercontent.com/arlotito/vm-iotedge-provision/dev/scripts/edge-config.sh"
export EDGE_INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/arlotito/vm-iotedge-provision/dev/scripts/edge-install.sh"


# print info
summary_vm () {
    echo
    echo
    echo "SUMMARY"
    echo "----------------------------------------"
    echo "VM"
    echo "  - name:         $VM_NAME"
    echo "  - rg:           $VM_RG"
    echo "  - fqdn:         $HOST_IP"
    echo "  - username:     $HOST_USERNAME"
    echo "  - ssh keys:     $SSH_KEY_PRIVATE, $SSH_KEY_PUB"
    echo
    echo "to connect to the VM:"
    echo "  ssh $HOST_USERNAME@$HOST_IP -i $SSH_KEY_PUB"
}

summary_hub () {
    echo ""
    echo "IoT HUB"
    echo "  - name:         $HUB_NAME"
    echo "  - device ID:    $DEVICE_NAME"
    echo "  - conn string:  $CONN_STRING"
}

create_keys () {
    # create ssh keys if not already there
    if [ ! -f "${SSH_KEY_PRIVATE}" ] || [ ! -f "${SSH_KEY_PUB}" ]; 
    then
        echo "creating SSH keypair..."
        mkdir -p $SSH_KEY_FOLDER
        ssh-keygen -b 2048 -t rsa -f "${SSH_KEY_FOLDER}/${SSH_KEY_NAME}" -q -N ""
        mv ${SSH_KEY_FOLDER}/${SSH_KEY_NAME} $SSH_KEY_PRIVATE
        chmod 400 $SSH_KEY_PRIVATE
        chmod 444 $SSH_KEY_PUB
    fi
}

create_rg () {
    echo "creating resource group '$VM_RG'..."
    result=$(az group create --location westeurope --resource-group $VM_RG | jq -r .properties.provisioningState)
    if [ "$result" != "Succeeded" ]; 
    then
        echo -e "${RED}ERROR!${NC}"
        exit 1
    fi
}

create_vm () {
    echo "creating vm '$VM_NAME'..."
    result=$(az vm create --name $VM_NAME -g $VM_RG \
        --public-ip-address-dns-name $VM_NAME --public-ip-sku Standard \
        --image Canonical:UbuntuServer:18.04-LTS:latest \
        --size $vmSize \
        --admin-username $HOST_USERNAME \
        --ssh-key-values $SSH_KEY_PUB \
        | jq -r .fqdns
    )
    if [ "$result" == "" ]; 
    then
        echo -e "${RED}ERROR!${NC}"
        exit 1
    fi

    export HOST_IP=$result

    echo "setting vm autoshutdown at '$VM_SHUTDOWN_TIME'..."
    result=$(az vm auto-shutdown \
        --name $VM_NAME -g $VM_RG \
        --time $VM_SHUTDOWN_TIME | jq -r .id
    )
    if [ "$result" == "" ]; 
    then
        echo -e "${RED}ERROR!${NC}"
        exit 1
    fi
}

iothub_register () {
    # register iot edge identity
    echo "register the edge device identity '$DEVICE_NAME' with the IoT HUB '$HUB_NAME'..."
    result=$(az iot hub device-identity create \
        -n $HUB_NAME \
        -d $DEVICE_NAME \
        --ee | jq -r .status
    )
    if [ "$result" != "enabled" ]; 
    then
        echo -e "${RED}ERROR!${NC}"
        exit 1
    fi

    echo "getting the edge device connection string..."
    result=$(az iot hub device-identity connection-string show \
        -n $HUB_NAME \
        -d $DEVICE_NAME | jq -r .connectionString)
    if [ "$result" == "" ]; 
    then
        echo -e "${RED}ERROR!${NC}"
        exit 1
    fi

    export CONN_STRING=$result
}

iotedge_install () {
    echo "installing iot edge ${edgeVersion} (output written to ./vm.log)..."
    result=$(ssh $HOST_USERNAME@$HOST_IP -i $SSH_KEY_PRIVATE -t "bash -s" -- < edge-install.sh -e "${edgeVersion}" 1>vm.log 2>vm.log )

    ssh $HOST_USERNAME@$HOST_IP -i $SSH_KEY_PRIVATE wget ${EDGE_INSTALL_SCRIPT_URL}
    ssh $HOST_USERNAME@$HOST_IP -i $SSH_KEY_PRIVATE chmod +x edge-install.sh
    ssh $HOST_USERNAME@$HOST_IP -i $SSH_KEY_PRIVATE chmod +x ./edge-install.sh -e "${edgeVersion}"

}

iotedge_configure () {
    echo "configuring iot edge with the provisioned edge device identity (output written to ./vm.log)..."

    ssh $HOST_USERNAME@$HOST_IP -i $SSH_KEY_PRIVATE wget ${EDGE_CONFIG_SCRIPT_URL}
    ssh $HOST_USERNAME@$HOST_IP -i $SSH_KEY_PRIVATE chmod +x edge-config.sh
    ssh $HOST_USERNAME@$HOST_IP -i $SSH_KEY_PRIVATE chmod +x ./edge-config.sh -e "${edgeVersion}" -c ${CONN_STRING@Q}

    if [ "$deploymentManifest" != "" ]; 
    then
        # deploy
        echo "deploying manifest '$deploymentManifest'..."
        result=$(az iot edge set-modules \
            -n $HUB_NAME \
            -d $DEVICE_NAME \
            --content $deploymentManifest)
    fi
}

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

create_keys
create_rg
create_vm

if [ "$HUB_NAME" ];
then
    iothub_register
fi

if [ "$edgeVersion" ];
then
    # wait a bit 
    echo "wait a while for the VM to boot (10s)..."
    sleep 10

    # add the host's key to the known-host (to avoid the prompt later on)
    echo "adding host pub key to ~/.ssh/known_hosts..."
    ssh-keyscan -t ssh-rsa $HOST_IP >> ~/.ssh/known_hosts

    # install iotedge
    iotedge_install

    if [ "$HUB_NAME" ];
    then
        iotedge_configure   
    fi

    # wait a bit 
    echo "wait a while for the edge modules to start (10s)..."
    sleep 10

    # checks
    echo "remotely connecting to VM to check whether IoT Edge is up and running:"
    ssh $HOST_USERNAME@$HOST_IP -i $SSH_KEY_PRIVATE -t "iotedge version"
    ssh $HOST_USERNAME@$HOST_IP -i $SSH_KEY_PRIVATE -t "iotedge list"
fi

echo
echo "done!"
echo
echo

summary_vm

if [ "$HUB_NAME" ];
then
    summary_hub
fi

if [ "$login" = "true" ]; 
then
    echo "login into machine..."
    ssh $HOST_USERNAME@$HOST_IP -i $SSH_KEY_PRIVATE
fi

exit 0