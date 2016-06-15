#!/bin/bash

which docker
if [ "$?" != "0" ]; then
  curl https://get.docker.com/ | bash -
  sudo usermod -aG docker ubuntu
fi

sudo apt-get install -y virtualenv python-pip
virtualenv venv
venv/bin/activate
pip install git+git://github.com/kellrott/gwftool.git

