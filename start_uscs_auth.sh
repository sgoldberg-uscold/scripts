#!/bin/bash

pushd /Users/sgoldberg/Documents/Projects/uscs-auth/uscs-auth

java \
	-Dspring.config.location=/Users/sgoldberg/Documents/Projects/ALL_CONFIGS/CAS/application.yaml \
	-jar ./target/uscs-auth-1.0.jar

popd
