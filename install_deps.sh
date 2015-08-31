#!/bin/bash
apt-get update
apt-get install --no-install-recommends -y git
apt-get install --no-install-recommends -y cpanminus
apt-get install --no-install-recommends -y puppet
apt-get install --no-install-recommends -y make
apt-get install --no-install-recommends -y gcc libssl-dev
apt-get install --no-install-recommends -y libyaml-libyaml-perl
cpanm Carton
carton install
