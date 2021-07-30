A bash script to spin-up a VM with a fully provisioned Azure IoT Edge ready to be used.

It's easy as:
```bash
./vm-iotedge-provision.sh \
    -s Standard_DS2_v2 -g edge-benchmark-vm-rg \
    -e 1.2 \
    -n my-iot-hub \
    -d ./manifests/empty-1.2.json 
```

It will:
* create a VM of the given size ('Standard_DS2_v2') in the given resource group ('edge-benchmark-vm-rg')
* install IoT Edge (version 1.2)
* register an identity into the IoT HUB ('my-iot-hub') and configure the IoT Edge to connect to it
* deploy the manifest ('./manifests/empty-1.2.json')

Here's the output:
```
creating resource group 'edge-benchmark-vm-rg'...
creating vm 'standard-ds2-v2-edge-1-2-1627639870'...
setting vm autoshutdown at '2100'...
register the edge device identity 'standard-ds2-v2-edge-1-2-1627639870' with the IoT HUB 'my-iot-hub'...
getting the edge device connection string...
wait a while for the VM to boot (10s)...
adding host pub key to ~/.ssh/known_hosts...
installing iot edge 1.2...
configuring iot edge with the provisioned edge device identity...
deploying manifest './manifests/empty-1.2.json'...
wait a while for the modules to start (10s)...
done!


remotely connecting to VM to check whether IoT Edge is up and running:
iotedge 1.2.3
Connection to standard-ds2-v2-edge-1-2-1627639870.westeurope.cloudapp.azure.co closed.
NAME             STATUS           DESCRIPTION      CONFIG
edgeAgent        running          Up 11 seconds    mcr.microsoft.com/azureiotedge-agent:1.2
edgeHub          running          Up 5 seconds     mcr.microsoft.com/azureiotedge-hub:1.2
Connection to standard-ds2-v2-edge-1-2-1627639870.westeurope.cloudapp.azure.co closed.


SUMMARY
----------------------------------------
VM
  - name:         standard-ds2-v2-edge-1-2-1627639870
  - rg:           edge-benchmark-vm-rg
  - fqdn:         standard-ds2-v2-edge-1-2-1627639870.westeurope.cloudapp.azure.com
  - username:     arlotito
  - ssh keys:     ./keys/vm.pub, ./keys/vm

IoT HUB
  - name:         my-iot-hub
  - device ID:    standard-ds2-v2-edge-1-2-1627639870
  - conn string:  HostName=my-iot-hub.azure-devices.net;DeviceId=standard-ds2-v2-edge-1-2-1627639870;SharedAccessKey=ZzpXRtbuOdZnbjqSM2AVs********************=

to connect to the VM:
  ssh arlotito@standard-ds2-v2-edge-1-2-1627639870.westeurope.cloudapp.azure.com -i ./keys/vm
```

NOTE:
All operations on the remote machine are done via SSH.
A key pair is automatically created.

# Usage
```bash
./vm-iotedge-provision.sh -h

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

Example:
    ./vm-iotedge-provision.sh -s Standard_DS2_v2 -g edge-benchmark-vm-rg -d ./manifests/empty-1.2.json -e 1.2 -n my-iot-hub

Prerequisites:
    - ssh client
    - az cli with iot extension (https://github.com/Azure/azure-iot-cli-extension)

Note:
If not already signed-in, do 'az login' and select the tenant/subscription where you want to operate.
```