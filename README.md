
# Introduction

The main script of this project is the [kind\_helper.py](https://github.com/MoserMichael/kind-helper/blob/master/kind_helper.py), this script sets up a k8s test cluster for test purposes, it uses the [kind](https://kubernetes.io/docs/setup/learning-environment/kind/) utility.

With a kubernetes cluster created by kind you can have any number of nodes that are run on the same machine; the resource consumption is not very high and the cluster starts up quickly; It creates a reasonable kubernetes test cluster that can be used in automated tests. The kind tool is a bit difficult to use at times, therefore the kind\_helper.py script is designed to simplify the process of setting up/tearing down of a test cluster with kind.

# What it does

the following steps are done when creating a test cluster:

1. the script first downloads kind and kubectl (if not present)
2. starts a local docker registry 
3. creates a kind cluster with desired number of master and worker nodes that is connected to the local docker registry.
4. script waits for all nodes to become ready

The kind\_helper.py script requires presence of docker and python3.

Example usage is in the test for this project (main test script: [test.sh](https://github.com/MoserMichael/kind-helper/blob/master/test/test.sh) see [test/](https://github.com/MoserMichael/kind-helper/tree/master/test) directory)

# Command line reference

Here is the command line of this programm:

```
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
  --plat PLATFORM, -t PLATFORM
                        platform id for downloading kind and curl (if needed)
                        (default: amd64)
  --verbose, -v         verbose output (default: False)

```

