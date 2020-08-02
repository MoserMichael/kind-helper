
## Introduction

The main deliverable of this project is the [kind\_helper.py](https://github.com/MoserMichael/kind-helper/blob/master/kind_helper.py) script, this script sets up a kubernetes test cluster for test purposes; it uses the [kind](https://kubernetes.io/docs/setup/learning-environment/kind/) utility.

With a kubernetes cluster created by kind you can have any number of nodes that are run on the same machine; Each node of the cluster is hosted by a separate docker container; The resource consumption is therefore not very high and the cluster starts up quickly; It creates a reasonable kubernetes test cluster that can be used in automated tests. The kind tool is a bit difficult to use at times, therefore the kind\_helper.py script is designed to simplify the process of setting up/tearing down of a test cluster.

## What it does

The following steps are done by kind\_helper.py when creating a test cluster:

1. the script first downloads kind and kubectl (if these are not present in the path)
2. starts a local docker registry 
3. creates a kind cluster with desired number of master and worker nodes that is connected to the local docker registry. Any docker image pushed to this registry is available from within the test cluster.
4. script waits for all nodes to become ready
5. If command line option --ingress option is present, then create the ingress deployment and start the nginx load balancer on the first worker node (requires to have at least one worker node in the cluster). 

The kind\_helper.py script requires the presence of docker and python3.

## Example usage 

Examples are in the test for this project 

1. basic test without ingress [test-basic.sh](https://github.com/MoserMichael/kind-helper/blob/master/test/test-basic.sh) 
 creates a cluster; builds a docker image, puts it into the local registry; runs a deployment in the cluster that accesses the image in the local registry.
2. test with ingress [test-with-ingress.sh](https://github.com/MoserMichael/kind-helper/blob/master/test/test-with-ingress.sh)  same as (1), adds creation of an ingress to the cluster; registers a service and ingress object that access an http server in the running pod; waits for the ingress object to become active (i.e. associated with the load balancer); sends http request to the installation and checks that you get the expected response.

Also see [test/](https://github.com/MoserMichael/kind-helper/tree/master/test) directory for additional files.

`make test` will run all the tests.

## Command line reference

Here is the command line of this program:

```
usage: kind_helper.py [-h] [--start] [--masters NUM_MASTERS]
                      [--workers NUM_WORKERS] [--timeout TIMEOUT]
                      [--registry-port REG_DOCKER_PORT]
                      [--registry-name REG_DOCKER_NAME]
                      [--ingress INGRESS [INGRESS ...]] [--dir TEMP_DIR]
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
  --timeout TIMEOUT, -t TIMEOUT
                        timeout while waiting for nodes to become ready
                        (default: 120)
  --registry-port REG_DOCKER_PORT, -p REG_DOCKER_PORT
                        number of docker registery port (default: 5000)
  --registry-name REG_DOCKER_NAME, -n REG_DOCKER_NAME
                        docker registery name (default: kind-registry)
  --ingress INGRESS [INGRESS ...], -i INGRESS [INGRESS ...]
                        create an ingress with the test cluster if present.Add
                        multiple values of the following form <external-
                        port>:<internal-port;first is the port visible from
                        outside the cluster, second is the port inside the
                        cluster (default: )
  --dir TEMP_DIR, -d TEMP_DIR
                        if kind or kubectl tools not found then try to
                        download to this directory (default: $HOME/tmp-dir)
  --plat PLATFORM, -l PLATFORM
                        platform id for downloading kind and curl (if needed)
                        (default: amd64)
  --verbose, -v         verbose output (default: False)

Stop the cluster:
  --stop, -k            stop k8s kind cluster & local docker registry
                        (default: False)
  --dir TEMP_DIR, -d TEMP_DIR
                        if kind or kubectl tools not found then try to
                        download to this directory (default: $HOME/tmp-dir)
  --plat PLATFORM, -l PLATFORM
                        platform id for downloading kind and curl (if needed)
                        (default: amd64)
  --verbose, -v         verbose output (default: False)```

