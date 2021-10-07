TO DO:
* option to set a custom VM name (instead of using the auto-generated one)
* check dependencies (jq, az iot, ...) before starting

DONE:
* by default, store keys in $HOME/.ssh
* keypair filenames changed (vmedge.key and vmedge.pub)
* can be now run from the web
    ```bash
    curl -L https://raw.githubusercontent.com/arlotito/vm-iotedge-provision/dev/scripts/vmedge.sh | bash -s -- [params]
    ```

OTHER:
