#!/bin/bash

pushd /Users/sgoldberg/Documents/Projects

# Try to avoid "java.net.SocketException: Can't assign requested address"
# errors caused by IPv6.
#      -Djava.net.preferIPv4Stack=true \
        #-agentpath:/Users/jon.baker/Documents/architecture/LightRun/agent/lightrun_agent.so=--lightrun_extra_class_path=/Users/jon.baker/projects/project_1/hcserver/target/hcserver.jar \
        #-agentpath:/Users/jon.baker/Documents/architecture/LightRun/agent/lightrun_agent.so \

java \
    -Dspring.config.location=/Users/sgoldberg/Documents/Projects/ALL_CONFIGS/hcserver/application.yml \
    -Dhazelcast.config=/Users/sgoldberg/Documents/Projects/ALL_CONFIGS/hcserver/hazelcast.yml \
    -Dlog4j2.configurationFile=/Users/sgoldberg/Documents/Projects/ALL_CONFIGS/hcserver/log4j2.xml \
    -Dhazelcast.logging.type=log4j2 \
    -Djava.net.preferIPv4Stack=true \
    -Dhazelcast.rest.enabled=false \
    -Dhazelcast.diagnostics.enabled=false \
	-jar ./hcserver/target/hcserver.jar

popd
