
## Introduction

The main deliverable of this project is the [kind\_helper.py](https://github.com/MoserMichael/kind-helper/blob/master/kind_helper.py) script, this script sets up a kubernetes test cluster for test purposes; it uses the [kind](https://kubernetes.io/docs/setup/learning-environment/kind/) utility.

With a kubernetes cluster created by kind you can have any number of nodes that are run on the same machine; Each node of the cluster is hosted by a separate docker container; The resource consumption is therefore not very high and the cluster starts up quickly; It creates a reasonable kubernetes test cluster that can be used in automated tests. The kind tool is a bit difficult to use at times, therefore the kind\_helper.py script is designed to simplify the process of setting up/tearing down of a test cluster.

The number 'nodes' in the kind cluster is limited by the amount of available RAM. I didn't find any clear memory requirements for a node, so that I can't enforce any memory requirements in the script.

## What it does

The following steps are done by kind\_helper.py when creating a test cluster:

1. the script first downloads kind and kubectl (if these are not present in the path)
2. starts a local docker registry 
3. creates a kind cluster with desired number of master and worker nodes that is connected to the local docker registry. Any docker image pushed to this registry is available from within the test cluster.
4. download kubeconfig for working with kind cluster
5. script waits for all nodes to become ready
6. If command line option --ingress option is present, then create the ingress deployment and start the nginx load balancer on the first worker node (requires to have at least one worker node in the cluster). 

The kind\_helper.py script requires the presence of docker and python3.

## Example usage 

* Start a kind cluster with 1 master node and 3 worker nodes; local registry of cluster starts at port 5000 ```./kind_helper.py --start --workers 3`` --master 1 --verbose  --registry-port 5000```
* Run the kubectl command 'kubectl get nodes' with the kind clusters context ```./kind_helper.py -c 'get nodes'```
* run a shell on node kind-control-plane of the cluster ```./kind_helper.py --node kind-control-plane```
* stop the cluster & local registry ```./kind_helper.py --stop```

Examples are in the test for this project 

1. basic test without ingress [test-basic.sh](https://github.com/MoserMichael/kind-helper/blob/master/test/test-basic.sh) 
 creates a cluster; builds a docker image, puts it into the local registry; runs a deployment in the cluster that accesses the image in the local registry.
2. test with http ingress [test-with-ingress.sh](https://github.com/MoserMichael/kind-helper/blob/master/test/test-with-ingress.sh) in addition to (1): adds creation of an http ingress to the cluster; registers a service and ingress object that access an http server in the running pod; waits for the ingress object to become active (i.e. associated with the load balancer); sends http request to the installation and checks that you get the expected response.
3. test with https ingress [test-with-ingress-tls.sh](https://github.com/MoserMichael/kind-helper/blob/master/test/test-with-ingress-tls.sh)  modification of (2), adds creation of an https ingress to the cluster; creates self signed certificate, creates secret that refers to the certificate; registers a ingress object that does HTTPS termination and forwards clear http to one of the endpoints listed in the service, where the endpoints are the http servers running in the test pods; waits for the ingress object to become active (i.e. associated with the load balancer); sends https request to the installation and checks that you get the expected response.


Also see [test/](https://github.com/MoserMichael/kind-helper/tree/master/test) directory for additional files.

`make test` will run all the tests.

## setup 

Requires ```python3```, ```docker``` and ```bash``` to be installed. 

```kubectl``` and ```kind``` are downloaded by the script, if not present.

## Bugs/Limitation

* Currently it works on Linux - when running a cluster with one master, The problem is that the deployment of the ingress controller is ignoring the ```ingress-ready``` node selector.
* There is a problem on OSX (can't push to local docker registry from OSX, when docker desktop for OSX is installed§)
* For OSX there is the trick of running all this on ```dind``` (Docker in docker) - that's a linux docker image that allows you to run a docker server inside a docker container.
To do so: clone the project, change to project directory, then run the following (beware: the ```dind``` container is run in privileged mode)
```
docker run --privileged -v $PWD:/mystuff -d --name dind-test docker:dind
docker exec -it dind-test /bin/sh
# while running inside the container
apk update
apk add bash python3 jq curl make
make test 
```

## Command line reference

Here is the command line of this program:

```
usage: kind_helper.py [-h] [--start] [--masters NUM_MASTERS]
                      [--workers NUM_WORKERS] [--timeout TIMEOUT]
                      [--registry-port REG_DOCKER_PORT]
                      [--registry-name REG_DOCKER_NAME]
                      [--ingress INGRESS [INGRESS ...]] [--dir TEMP_DIR]
                      [--plat PLATFORM] [--verbose] [--stop] [--node NODE]
                      [--kubectl KUBECTL]

This program automates creation of useful k8s clusters by means of utilising
the kind utility. It runs a local docker registry and can be used

options:
  -h, --help            show this help message and exit

Start the cluster:
  --start, -s           start k8s kind cluster & local docker registry
                        (default: False)
  --masters NUM_MASTERS, -m NUM_MASTERS
                        number of master nodes (default: 1)
  --workers NUM_WORKERS, -w NUM_WORKERS
                        number of worker nodes (default: 1)
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
                        download to this directory (default: $HOME/kind-tmp-
                        dir)
  --plat PLATFORM, -l PLATFORM
                        platform id for downloading kind and kubectl (if needed)
                        (default: amd64)
  --verbose, -v         verbose output (default: False)

Stop the cluster:
  --stop, -k            stop k8s kind cluster & local docker registry
                        (default: False)
  --dir TEMP_DIR, -d TEMP_DIR
                        if kind or kubectl tools not found then try to
                        download to this directory (default: $HOME/kind-tmp-
                        dir)
  --plat PLATFORM, -l PLATFORM
                        platform id for downloading kind and kubectl (if needed)
                        (default: amd64)
  --verbose, -v         verbose output (default: False)

get shell to node:
  --node NODE, -e NODE  run shell in kind cluster node with this name
                        (default: )

kubectl wrapper - run kubectl on kind cluster:
  --kubectl KUBECTL, -c KUBECTL
                        value of options is a command line that is passed to
                        kubectl with kind cluster config (default: )
  --dir TEMP_DIR, -d TEMP_DIR
                        if kind or kubectl tools not found then try to
                        download to this directory (default: $HOME/kind-tmp-
                        dir)
```

## What I learned from this

doing docker based workflows can take quite a lot of time; i often need to try out stuff; now every iteration of the process takes quite a while, as it involves a combination of steps where each step takes quite a while: building the docker, building the cluster, trying things out on the cluster. One solution to this problem is not to rely on automation too much here - each step needs to be debugged on its own, without relying on the whole sequence of steps. (O(n^2) versus o(n)). Now with kubernetes you have an additional problem: often it is not obvious that an action failed or succeeded; you have to examine all of the effected kubernetes objects and their logs...

Local docker registrys using registry:2 have a lot of strange issues: i managed to push a docker image of the form aa/bb/cc:latest to the local registry on localhost:5000/dd:latest but not a docker image of the form aa/bb:latest

Also in kubernetes you really have to take care of annotations; a service object has an annotation in its spec, and expects all pods connected to the service to have that same annotation; likewise there are some annotatins involved with ingresses; etc.
 All that required some head banging on my part, for a while.
