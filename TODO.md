* by default, store keys in $HOME/.ssh
* option to set a custom VM name (instead of using the auto-generated one)
* single-file script that can be run from the web?
    ```bash
    alias edge-vm="curl -L https://raw.githubusercontent.com/arlotito/vm-iotedge-provision/dev/scripts/vm-iotedge-provision.sh  | bash -s --"
    edge-vm -s Standard_DS2_v2 -g est-tutorial -e 1.2
    ```