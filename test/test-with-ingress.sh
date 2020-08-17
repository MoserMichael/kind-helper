#!/usr/bin/env bash

set -ex

REGISTRY_PORT=5000
EXTERNAL_PORT=8001

# comment this to keep the cluster running on completion.
STOP_CLUSTER_ON_EXIT=1

docker_tag() {
	local from="$1"
	local to="$2"

	IMG=$(docker images --no-trunc --quiet "$from")
	docker tag $IMG $to
	docker push $to
}

find_kubectl() {
    set +e
    KUBECTL=$(which kubectl)
    STAT=$?
    set -e

    if [[ $STAT != 0 ]]; then
        # kubectl if not in path than kind_helper downloaded it into defaultl location
        KUBECTL=$HOME/tmp-dir/kubectl
    fi

}

# start the test cluster (3 workers, 3 masters)

# short options:
#./kind_helper.py -s -w 3 -i ${EXTERNAL_PORT}:80 -v -t 120  -p ${REGISTRY_PORT}

# the same with long options
./kind_helper.py --start --workers 3 --timeout 120 --ingress ${EXTERNAL_PORT}:80 --verbose --registry-port ${REGISTRY_PORT}

cleanup() {
    # kill the cluster on exit
    if [[ $STOP_CLUSTER_ON_EXIT != "" ]]; then
        ./kind_helper.py --stop
    fi
}

trap "cleanup" EXIT SIGINT


find_kubectl

# check if the nodes are up and ready

NODES=$(${KUBECTL} get nodes)

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

# create pod in registry that refers to kind registry
${KUBECTL} create -f test/service_account.yaml
${KUBECTL} create -f test/role.yaml  
${KUBECTL} create -f test/role_binding.yaml  
${KUBECTL} create -f test/deployment-port.yaml 
${KUBECTL} create -f test/service.yaml  
${KUBECTL} create -f test/ingress.yaml  

${KUBECTL} wait -f test/deployment.yaml --for condition=available

echo "*** deployment available ***"

${KUBECTL} get pods -o wide


echo "*** wait for ingress object to be active (be attached to load balancer) ***"

while [[ true ]]; do
    HAS_LB=$(${KUBECTL} get ingresses test-echo-server -n default -o json | jq .status.loadBalancer.ingress)
    echo "${HAS_LB}"
    if [[ $HAS_LB != "null" ]] && [[ $HAS_LB != "{}" ]]; then
      break
    fi
    sleep 3
done

${KUBECTL} get ingresses test-echo-server -n default -o yaml

RESPONSE=$(curl  http://localhost:${EXTERNAL_PORT}/test-echo-server)

echo "${RESPONSE}"

HAS_RESPONSE=$(echo "${RESPONSE}" | grep -c '<h2>echo response</h2>')
if [[ $HAS_RESPONSE != 1 ]]; then
    echo "Sorry, could not reach the service"
    exit 1
fi

echo "*** test completed ***"

