#!/bin/bash
apt-get update
apt-get install --no-install-recommends -y git-core ca-certificates
apt-get install --no-install-recommends -y cpanminus
apt-get install --no-install-recommends -y puppet-common
apt-get install --no-install-recommends -y make
apt-get install --no-install-recommends -y gcc libssl-dev
apt-get install --no-install-recommends -y libyaml-libyaml-perl
apt-get install --no-install-recommends -y libfile-slurp-perl
cpanm Carton
carton install
