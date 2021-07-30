A bash script to spin-up a VM with a fully provisioned Azure IoT Edge ready to be used.

It's easy as:
```bash
./vm-iotedge-provision.sh -s Standard_DS2_v2 -g edge-benchmark-vm-rg -d ./manifests/empty-1.2.json -e 1.2 -n my-iot-hub
```

It will:
* create a VM of the given size ('Standard_DS2_v2')
* register an identity into the IoT HUB ('my-iot-hub')
* install IoT Edge (version 1.2)
* configure it to connect to the iot hub
* deploy the manifest ('./manifests/empty-1.2.json')

