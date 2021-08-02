#!/bin/bash

# install git
sudo yum -y install git

# download go, then install it
wget https://dl.google.com/go/go1.14.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.14.linux-amd64.tar.gz

# clone the hello world app.
# The app is hosted on private repo,
# that's why the github token is used on cloning the repo
github_token=30542dd8874ba3745c55203a091c345340c18b7a
git clone https://$github_token:x-oauth-basic@github.com/novalagung/hello-world.git \
    && echo "cloned" \
    || echo "clone failed"

# export certain variables required by go
export GO111MODULE=on
export GOROOT=/usr/local/go
export GOCACHE=~/gocache
mkdir -p $GOCACHE
export GOPATH=~/goapp
mkdir -p $GOPATH

# create local vars specifically for the app
export PORT=8080
export INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`

# build the app
cd hello-world
/usr/local/go/bin/go env
/usr/local/go/bin/go mod tidy
/usr/local/go/bin/go build -o binary

# run the app with nohup
nohup ./binary &