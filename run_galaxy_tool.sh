#!/bin/bash

docker run -p 18080:80 \
-v `pwd`/extra_entries:/local_tools \
--privileged=true -e DOCKER_PARENT=True \
-v /var/run/docker.sock:/var/run/docker.sock \
-e GALAXY_CONFIG_TOOL_CONFIG_FILE=config/tool_conf.xml.sample,config/shed_tool_conf.xml.sample,/local_tools/tool_conf.xml \
bgruening/galaxy-stable
