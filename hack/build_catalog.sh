#!/bin/bash


set -e

export DOCKER_DEFAULT_PLATFORM=linux/amd64


VERSION=${VERSION:-latest}
OPERATOR_IMAGE=lightspeed-operator@sha256:c27acc1d6db151d9f463c8e0936356724f3e57cee4f358b82478b056b6b61377
REPLACE_IMAGE=lightspeed-operator:latest

#rm -rf ./bundle
#make bundle VERSION=$VERSION
#"s/name: analytics-operator.v0.1.0/name: analytics-operator.v$VERSION/"
sed -i.bak "s/name: lightspeed-operator.v0.0.0/name: lightspeed-operator.v$VERSION/" bundle/manifests/lightspeed-operator.clusterserviceversion.yaml
sed -i.bak "s/version: 0.0.0/version: $VERSION/" bundle/manifests/lightspeed-operator.clusterserviceversion.yaml
sed -i.bak "s/$REPLACE_IMAGE/$OPERATOR_IMAGE/" bundle/manifests/lightspeed-operator.clusterserviceversion.yaml
make bundle-build bundle-push VERSION=$VERSION

#make catalog-build catalog-push VERSION=$VERSION



