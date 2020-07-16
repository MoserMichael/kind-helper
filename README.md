
This script sets up a k8s test cluster for test purposes, it uses the [kind](https://kubernetes.io/docs/setup/learning-environment/kind/) utility.

The script requires presence of docker.

It first downloads kind and kubectl,
starts a local registry and then creates a kind cluster that is connected to the local registry.

Here is the command line of this programm:

```
./kind_helper.py -h
usage: kind_helper.py [-h] [--start] [--masters NUM_MASTERS]
                      [--workers NUM_WORKERS]
                      [--registry-port REG_DOCKER_PORT]
                      [--registry-name REG_DOCKER_NAME] [--dir TEMP_DIR]
                      [--plat PLATFORM] [--verbose] [--stop]

This program automates creation of useful k8s clusters by means of utilising
the kind utility. It runs a local docker registry and can be used

optional arguments:
  -h, --help            show this help message and exit

Start the cluster:
  --start, -s           start k8s kind cluster & local docker registry
                        (default: False)
  --masters NUM_MASTERS, -m NUM_MASTERS
                        number of master nodes (default: 3)
  --workers NUM_WORKERS, -w NUM_WORKERS
                        number of worker nodes (default: 0)
  --registry-port REG_DOCKER_PORT, -p REG_DOCKER_PORT
                        number of docker registery port (default: 8000)
  --registry-name REG_DOCKER_NAME, -n REG_DOCKER_NAME
                        docker registery name (default: kind-registry)
  --dir TEMP_DIR, -d TEMP_DIR
                        if kind or kubectl tools not found then try to
                        download to this directory (default: $HOME/tmp-dir)
  --plat PLATFORM, -t PLATFORM
                        platform id for downloading kind and curl (if needed)
                        (default: amd64)
  --verbose, -v         verbose output (default: False)

Stop the cluster:
  --stop, -k            stop k8s kind cluster & local docker registry
                        (default: False)
  --dir TEMP_DIR, -d TEMP_DIR
                        if kind or kubectl tools not found then try to
                        download to this directory (default: $HOME/tmp-dir)
  --verbose, -v         verbose output (default: False)

```

