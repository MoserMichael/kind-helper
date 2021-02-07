#!/bin/bash

set -ex

cd / 

if [[ -z $GITHUB_TOKEN ]]; then
    echo "token does not exist, can't upload"
    exit 1
fi

git clone https://github.com/MoserMichael/kind-helper.git helper
pushd helper

git config --global user.email "a@gmail.com"
git config --global user.name "MoserMichael"

export GITHUB_USER=$(git config --global user.name)

# generate some action in the main repository, so that the CI job will not get disabled.
git checkout master
date >> ci-runs.txt
git add ci-runs.txt
git commit -m "automatic build $(date)"
expect -f ./build/ex

popd

