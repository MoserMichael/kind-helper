#!/usr/bin/python3

import argparse
import urllib.request
import json
import os
import pathlib
import subprocess
import shlex
import sys
import stat

KIND_DOWNLOAD_LOCATION = "https://api.github.com/repos/kubernetes-sigs/kind/releases/latest"
LATEST_K8S_VERSION = "https://storage.googleapis.com/kubernetes-release/release/stable.txt"
KUBECTL_LOCATION = \
        "https://storage.googleapis.com/kubernetes-release/release/{}/bin/linux/{}/kubectl"

def show_error(msg):
    print("Error {}".format(msg))
    sys.exit(1)

class RunCommand:
    def __init__(self, command_line, pipe_as_input=None, capture_stdout=True):
        self.command_line = command_line
        self.exit_code = 0
        self.run(command_line, pipe_as_input, capture_stdout)

    def run(self, command_line, pipe_as_input, capture_stdout):
        try:
            if pipe_as_input is None:
                process = subprocess.Popen(shlex.split(command_line), \
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)

                (output, error_out) = process.communicate()
                self.exit_code = process.wait()

                self.output = output.decode("utf-8")
                self.error_out = error_out.decode("utf-8")

            else:
                if capture_stdout:
                    process = subprocess.Popen(shlex.split(command_line), \
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, \
                                stderr=subprocess.PIPE)
                    (output, error_out) = process.communicate(input=pipe_as_input.encode("utf-8"))

                    self.output = output.decode("utf-8")
                    self.error_out = error_out.decode("utf-8")

                else:
                    process = subprocess.Popen(shlex.split(command_line), \
                                stdin=subprocess.PIPE)
                    process.communicate(input=pipe_as_input.encode("utf-8"))
                    self.output = ""
                    self.error_out = ""

                self.exit_code = process.wait()


            return self.exit_code
        except FileNotFoundError:
            self.output = ""
            self.error_out = "file not found"
            self.exit_code = 1
            return self.exit_code

    def result(self):
        return self.exit_code, self.output

    def make_error_message(self):
        return_value = ""
        if self.command_line != "":
            return_value += " command line: {}.".format(self.command_line)
        if self.exit_code != 0:
            return_value += " exit status: {}. ".format(self.exit_code)
        if self.error_out != "":
            return_value += " " + self.error_out
        return return_value

def has_command(file):
    cmd = "{} --version".format(file)
    cmd_runner = RunCommand(cmd)
    if cmd_runner.exit_code == 0:
        return True
    return False

def is_exe(localfile):
    file_check = pathlib.Path(localfile)
    if file_check.is_file() and os.access(localfile, os.X_OK):
        return True
    return False

def download(cmd, url, local_file=None):

    print("downloading {} to {} ...".format(url, local_file))

    filedata = urllib.request.urlopen(url)
    datatowrite = filedata.read()

    if filedata.code != 200:
        print("failed to downloadurl {} status code {}".format(url, filedata.code))
        return False, filedata.code, ""

    if cmd == "get_str":
        return True, filedata.code, datatowrite.decode("utf-8")
    if cmd == "save":
        if local_file is None:
            print("No local file for save")
            return False, -1, ""
        with open(local_file, 'wb') as output_file:
            output_file.write(datatowrite)
        return True, filedata.code, ""

    print("Illegal command to download {}".format(cmd))
    return False, filedata.code, ""


def download_exe(url, localfile):
    status, code, _ = download("save", url, localfile)
    if not status:
        show_error("failed to download url: {} to {}".format(url, localfile))

    res_stat = os.stat(localfile)
    os.chmod(localfile, res_stat.st_mode | stat.S_IEXEC)

    return status, code

def download_kind(local_file, platform):
    status, http_status, download_spec = download("get_str", KIND_DOWNLOAD_LOCATION)
    if not status:
        show_error("Failed to download kind downloads spec from {}. http status {}".\
                format(KIND_DOWNLOAD_LOCATION, http_status))

    spec_data = json.loads(download_spec)

    download_url = ""

    assets = spec_data.get("assets")
    if assets is None:
        show_error("Can't get kind download url - unexpected format of json")
    for asset in assets:
        kind_platform = "kind-linux-{}".format(platform)
        name = asset.get("name")
        if name is None:
            show_error("Can't get kind download url - unexpected format of json (2)")
        if name == kind_platform:
            download_url = asset.get("browser_download_url")
            if download_url is None:
                show_error("Can't get kind download url - unexpected format of json (3)")
            break

    print("kind download url {}".format(download_url))

    if download_url == "":
        show_error("failed to parse download location of kind tool")

    status, _ = download_exe(download_url, local_file)
    return status

def download_kubectl(local_file, platform):
    status, http_status, version = download("get_str", LATEST_K8S_VERSION)
    if not status:
        show_error("Failed to download name of latest kubernetes version from {}. http status {}".\
                format(LATEST_K8S_VERSION, http_status))

    url = KUBECTL_LOCATION.format(version.rstrip(), platform)

    print("url {} #".format(url))
    status, _ = download_exe(url, local_file)

    return status

def check_prerequisites(cmd_args):

    if not has_command("docker"):
        show_error("can't find docker in the current path. please install docker")

    has_kind = has_command("kind")
    has_kubectl = has_command("kubectl")

    if not has_kind or not has_kubectl:
        cmd_args.temp_dir = os.path.expandvars(cmd_args.temp_dir)
        dir_check = pathlib.Path(cmd_args.temp_dir)
        if not dir_check.is_dir():
            try:
                os.makedirs(cmd_args.temp_dir, 0o755)
            except OSError:
                show_error("can't create temp directory {}".format(cmd_args.temp_dir))

    if not has_kind:
        kind = "{}/kind".format(cmd_args.temp_dir)
        if not is_exe(kind):
            download_kind(kind, cmd_args.platform)
    else:
        kind = "kind"

    if not has_kubectl:
        kubectl = "{}/kubectl".format(cmd_args.temp_dir)
        if not is_exe(kubectl):
            download_kubectl(kubectl, cmd_args.platform)
    else:
        kubectl = "kubectl"

    os.environ["KUBECTL"] = kubectl
    os.environ["KIND"] = kind


def run_cluster(cmd_args):

    os.environ["reg_name"] = cmd_args.reg_docker_name
    os.environ["reg_port"] = str(cmd_args.reg_docker_port)
    os.environ["num_nodes"] = str(cmd_args.num_workers + cmd_args.num_masters)

    node_def = ""
    for _ in range(0, cmd_args.num_workers):
        node_def += "- role: worker\n"

    for _ in range(0, cmd_args.num_masters):
        node_def += "- role: control-plane\n"

    script_start = '''

set -e

# create registry container unless it already exists

running="$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)"
if [ "${running}" != 'true' ]; then
  docker run \
    -d --restart=always -p "${reg_port}" --name "${reg_name}" \
    registry:2
fi

# create a cluster with the local registry enabled in containerd
cat <<EOF | ${KIND} create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
'''

    script_end = '''
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${reg_port}"]
    endpoint = ["http://${reg_name}:${reg_port}"]
EOF

docker network connect "kind" "${reg_name}"

# tell https://tilt.dev to use the registry
# https://docs.tilt.dev/choosing_clusters.html#discovering-the-registry
#for node in $(${KIND} get nodes); do
for node in $(${KUBECTL} get nodes | sed '1d' | awk '{print $1}'); do
  ${KUBECTL} annotate node "${node}" "kind.x-k8s.io/registry=localhost:${reg_port}";
done

READY_NODES=$(${KUBECTL} get nodes | awk '{ print $2 }' | grep -c '^Ready$') || true
while [[ ${READY_NODES} -lt ${num_nodes} ]]; do
  echo "${READY_NODES}/${num_nodes} ready. waiting..."
  sleep 3s
  READY_NODES=$(${KUBECTL} get nodes | awk '{ print $2 }' | grep -c '^Ready$') || true
done

echo "*** kind cluster running, all nodes are ready ***"
'''
    script = script_start + node_def  + script_end

    bashcmd = "/bin/bash"
    if cmd_args.verbose:
        #print("script: {}".format(script))
        bashcmd += " -x"

    run_start = RunCommand(bashcmd, script, False)
    if run_start.exit_code == 0:
        print("*** cluster is running ***")
    else:
        show_error("Failed to run cluster: {}".format(run_start.make_error_message()))



def start_cluster(cmd_args):
    check_prerequisites(cmd_args)
    run_cluster(cmd_args)

def stop_cluster_imp(cmd_args):
    os.environ["reg_name"] = cmd_args.reg_docker_name
    os.environ["reg_port"] = str(cmd_args.reg_docker_port)

    script = '''

    set -e

${KIND} delete cluster

REG=$(docker ps | grep registry:2[[:space:]] | awk '{ print $1 }')
docker stop $REG
docker rm $REG
docker network rm kind
'''

    bashcmd = "/bin/bash"
    if cmd_args.verbose:
        #print("script: {}".format(script))
        bashcmd += " -x"

    run_start = RunCommand(bashcmd, script, False)
    if run_start.exit_code == 0:
        print("*** cluster is stopped ***")
    else:
        show_error("Failed to stop cluster: {}".format(run_start.make_error_message()))


def stop_cluster(cmd_args):
    check_prerequisites(cmd_args)
    stop_cluster_imp(cmd_args)

def parse_cmd_line():
    usage = '''
This program automates creation of useful k8s clusters by means of utilising the kind utility.

It runs a local docker registry and can be used

'''

    ### the formatter_class argument makes argumentParser print the default values of the options.
    ### wow. Lots of batteries included.
    parse = argparse.ArgumentParser(description=usage, \
                formatter_class=argparse.ArgumentDefaultsHelpFormatter)

    group = parse.add_argument_group("Start the cluster")

    group.add_argument('--start', '-s', action='store_true', default=False, dest='isstart',\
            help='start k8s kind cluster & local docker registry')

    group.add_argument('--masters', '-m', type=int, default=3, dest='num_masters',\
            help='number of master nodes')

    group.add_argument('--workers', '-w', type=int, default=0, dest='num_workers',\
            help='number of worker nodes')

    group.add_argument('--registry-port', '-p', type=int, default=8000,\
            dest='reg_docker_port',\
            help='number of docker registery port')

    group.add_argument('--registry-name', '-n', type=str, default="kind-registry", \
            dest='reg_docker_name', help='docker registery name')

    dir_opt = group.add_argument('--dir', '-d', type=str, dest='temp_dir', default="$HOME/tmp-dir",\
            help='if kind or kubectl tools not found then try to download to this directory')

    group.add_argument('--plat', '-t', type=str, dest='platform', default="amd64", \
            help='platform id for downloading kind and curl (if needed)')

    verbose_opt = group.add_argument('--verbose', '-v', action='store_true', default=False, \
            dest='verbose', help='verbose output')

    group = parse.add_argument_group("Stop the cluster")

    group.add_argument('--stop', '-k', action='store_true', default=False, dest='isstop',\
            help='stop k8s kind cluster & local docker registry')

    # that's the trick for having the same option in two groups
    group._group_actions.append(dir_opt)
    group._group_actions.append(verbose_opt)


    return parse.parse_args(), parse



def main():
    cmd_args, cmd_parser = parse_cmd_line()

    if cmd_args.isstart:
        start_cluster(cmd_args)
    elif cmd_args.isstop:
        stop_cluster(cmd_args)
    else:
        cmd_parser.print_help()


if __name__ == '__main__':
    main()
