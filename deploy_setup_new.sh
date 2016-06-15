#!/bin/bash

curl https://get.docker.com/ | bash -
sudo usermod -aG docker ubuntu

virtualenv venv
env/bin/activate
pip install git+git://github.com/kellrott/gwftool.git

