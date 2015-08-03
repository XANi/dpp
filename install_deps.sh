#!/bin/bash
apt-get update
apt-get install -y git
apt-get install -y cpanminus
apt-get install -y puppet
apt-get install -y make
apt-get install -y gcc libssl-dev
cpanm Carton
carton install
