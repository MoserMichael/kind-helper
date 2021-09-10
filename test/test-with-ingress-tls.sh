#!/usr/bin/env bash

set -ex
export PS4='+($(date +%H:%M:%S) ${BASH_SOURCE}:${LINENO})' 
exec &> >(tee ./test-with-ingress-tls.log)

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

# start the test cluster (3 workers, 3 masters)

# short options:
#./kind_helper.py -s -w 3 -i ${EXTERNAL_PORT}:443 -v -t 120  -p ${REGISTRY_PORT}

# the same with long options
./kind_helper.py --start --workers 3 --timeout 120 --ingress ${EXTERNAL_PORT}:443 --verbose --registry-port ${REGISTRY_PORT}

cleanup() {
    echo "*** cleanup ***"
    ./kind_helper.py -c 'get events'
    ./kind_helper.py -c 'get ing test-echo-server'
    ./kind_helper.py -c 'describe ing test-echo-server'
    ./kind_helper.py -c 'get deployment test-echo-server'
    ./kind_helper.py -c 'get pods -l test-echo-server'
    ./kind_helper.py -c 'get logs -l test-echo-server'

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

# create self signed certificate for ingress
KEY_FILE=test/ingress-key.pem
CERT_FILE=test/ingress-cert.pem
HOST=localhost

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ${KEY_FILE} -out ${CERT_FILE} -subj "/CN=${HOST}/O=${HOST}"

# create secret object that refers to certificate
SECRET_NAME=ingress-secret-cert

./kind_helper.py -c "create secret tls ${SECRET_NAME} --key ${KEY_FILE} --cert ${CERT_FILE}"

# build image for test pod
docker build -f test/Dockerfile.test -t aaa/mm/kind-test-pod .

# put docker into the local kind registry
docker_tag aaa/mm/kind-test-pod localhost:${REGISTRY_PORT}/kind-test-pod 

# adjust port number in container image name
sed -e s/PORTNUM/${REGISTRY_PORT}/ test/deployment.yaml >test/deployment-port.yaml

# create pod in registry that refers to kind registry
./kind_helper.py -c 'create -f test/service_account.yaml'
./kind_helper.py -c 'create -f test/role.yaml'
./kind_helper.py -c 'create -f test/role_binding.yaml'
./kind_helper.py -c 'create -f test/deployment-port.yaml'
./kind_helper.py -c 'create -f test/service.yaml'
./kind_helper.py -c 'create -f test/ingress-tls.yaml'

./kind_helper.py -c 'wait -f test/deployment.yaml --for condition=available'

echo "*** deployment available ***"

./kind_helper.py -c 'get pods -o wide'


echo "*** wait for ingress object to be active (be attached to load balancer) ***"

COUNT=0
while [[ true ]]; do 

    HAS_LB=$(./kind_helper.py -c 'get ingresses test-echo-server -n default -o json' | jq .status.loadBalancer.ingress)
    echo "${HAS_LB}"
    if [[ $HAS_LB != "null" ]] && [[ $HAS_LB != "{}" ]]; then
      break
    fi
    sleep 3

    if [[ $COUNT -gt 200 ]]; then
        echo "waiting too long for ingress to be available, exit with error..."
        ./kind_helper.py -c 'get ingresses test-echo-server -n default -o json'
        ./kind_helper.py -c 'get get pods -n default'
        exit 1
    fi
    ((COUNT+=1))
done

./kind_helper.py -c 'get ingresses test-echo-server -n default -o yaml'

RESPONSE=$(curl -k -v https://localhost:${EXTERNAL_PORT}/test-echo-server)

echo "${RESPONSE}"

HAS_RESPONSE=$(echo "${RESPONSE}" | grep -c '<h2>echo response</h2>')
if [[ $HAS_RESPONSE != 1 ]]; then
    echo "Sorry, could not reach the service"
    exit 1
fi

echo "*** test completed ***"

