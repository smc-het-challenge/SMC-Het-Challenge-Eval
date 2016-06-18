#!/bin/bash


GALAXY_USER=galaxy
GALAXY_UID=1450
GALAXY_GID=1450
GALAXY_HOME=/home/galaxy

sudo groupadd -r $GALAXY_USER -g $GALAXY_GID
sudo useradd -u $GALAXY_UID -r -g $GALAXY_USER -d $GALAXY_HOME -c "Galaxy user" $GALAXY_USER —shell /bin/bash
sudo mkdir /home/galaxy
sudo cp /etc/skel/.* /home/galaxy/
sudo chown galaxy:galaxy /home/galaxy

#which docker
#if [ "$?" != "0" ]; then
curl https://get.docker.com/ | bash -
sudo usermod -aG docker $GALAXY_USER
#fi

sudo apt-get install -y virtualenv python-pip
#virtualenv venv
#. venv/bin/activate
pip install git+git://github.com/kellrott/gwftool.git

