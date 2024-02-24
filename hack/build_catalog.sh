#!/bin/bash


set -e

export DOCKER_DEFAULT_PLATFORM=linux/amd64


VERSION=${VERSION:-latest}
OPERATOR_IMAGE= quay.io/openshift/lightspeed-service-api@sha256:8c941b183853e57d0ca00fe5201b724794c284790d83b1f39a688e4f1e7b2671


rm -rf ./bundle


make bundle VERSION=$VERSION

#make bundle-build bundle-push VERSION=$VERSION

#make catalog-build catalog-push VERSION=$VERSION



