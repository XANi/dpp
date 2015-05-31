#!/bin/bash
apt-get install git
apt-get install cpanminus
apt-get install puppet
apt-get install make
apt-get install gcc libssl-dev
cpanm Carton
carton install
