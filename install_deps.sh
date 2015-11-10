#!/bin/bash
<<<<<<< HEAD
apt-get install git
apt-get install cpanminus
apt-get install puppet-common
apt-get install make
apt-get install gcc
=======
apt-get update
apt-get install --no-install-recommends -y git-core ca-certificates
apt-get install --no-install-recommends -y cpanminus
apt-get install --no-install-recommends -y puppet
apt-get install --no-install-recommends -y make
apt-get install --no-install-recommends -y gcc libssl-dev
apt-get install --no-install-recommends -y libyaml-libyaml-perl
apt-get install --no-install-recommends -y libfile-slurp-perl
>>>>>>> e4fa7ea150751b0e460908d7ef9e344d4d3ea2e4
cpanm Carton
carton install
