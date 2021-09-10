#!/usr/bin/env bash

set -ex
export PS4='+($(date +%H:%M:%S) ${BASH_SOURCE}:${LINENO})' 
exec &> >(tee ./test-basic.log)

REGISTRY_PORT=5000

# comment thist to keep the cluster running on completion.
STOP_CLUSTER_ON_EXIT=1

docker_tag() {
	local from="$1"
	local to="$2"

	IMG=$(docker images --no-trunc --quiet "$from")
	docker tag $IMG $to
	docker push $to
}


# start the test cluster (3 workers, 3 masters)

# short options:
#./kind_helper.py -s -w 3 -v  -p ${REGISTRY_PORT}

# the same with long options
./kind_helper.py --start --workers 3 --verbose  --registry-port ${REGISTRY_PORT}

cleanup() {
    echo "*** cleanup ***"
    ./kind_helper.py -c 'get events'

    # kill the cluster on exit
    if [[ $STOP_CLUSTER_ON_EXIT != "" ]]; then
        ./kind_helper.py --stop
    fi
}

trap "cleanup" EXIT SIGINT

# check if the nodes are up and ready

NODES=$(./kind_helper.py -c 'get nodes')

READY_NODES=$(echo "$NODES" | grep -c Ready)
if [[ $READY_NODES != 6 ]]; then
    echo "Not all nodes up ${READY_NODES}/6"
    exit 1
fi

WORKER_NODES=$(echo "$NODES" | grep -c kind-worker)
if [[ $WORKER_NODES != 3 ]]; then
    echo "Not enough worker nodes ${WORKER_NODES}/3"
    exit 1
fi

MASTER_NODES=$(echo "$NODES" | grep -c kind-control-plane)
if [[ $MASTER_NODES != 3 ]]; then
    echo "Not enough worker nodes ${MASTER_NODES}/3"
    exit 1
fi

set +e
docker rmi aaa/mm/kind-test-pod localhost 
docker rmi localhost:${REGISTRY_PORT}/kind-test-pod 
set -e

# build image for test pod
docker build -f test/Dockerfile.test -t aaa/mm/kind-test-pod .

# put docker into the local kind registry
docker_tag aaa/mm/kind-test-pod localhost:${REGISTRY_PORT}/kind-test-pod 

# adjust port number in container image name
sed -e s/PORTNUM/${REGISTRY_PORT}/ test/deployment.yaml >test/deployment-port.yaml

# create pod in registry that refers to ./kind_helper.py kind registry
./kind_helper.py -c 'create -f test/service_account.yaml'
./kind_helper.py -c 'create -f test/role.yaml'
./kind_helper.py -c 'create -f test/role_binding.yaml'  
./kind_helper.py -c 'create -f test/deployment-port.yaml'
./kind_helper.py -c 'wait -f test/deployment.yaml --for condition=available'

echo "*** deployment available ***"

./kind_helper.py -c 'get pods -o wide'

echo "*** test completed ***"

