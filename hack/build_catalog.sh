#!/bin/bash


set -e

export DOCKER_DEFAULT_PLATFORM=linux/amd64


VERSION=0.0.43
OPERATOR_IMAGE=lightspeed-operator@sha256:2f18050dc1a81d6be1afba8e200a52d9dbd7e23346d089075ce8a64bdb619951
API_IMAGE=lightspeed-service-api@sha256:8c941b183853e57d0ca00fe5201b724794c284790d83b1f39a688e4f1e7b2671

REPLACE_OPERATOR_IMAGE=lightspeed-operator:$VERSION
REPLACE_API_IMAGE=lightspeed-service-api:latest

rm -rf ./bundle
make bundle VERSION=$VERSION
#"s/name: analytics-operator.v0.1.0/name: analytics-operator.v$VERSION/"
sed -i.bak "s/name: lightspeed-operator.v0.0.0/name: lightspeed-operator.v$VERSION/" bundle/manifests/lightspeed-operator.clusterserviceversion.yaml
sed -i.bak "s/version: 0.0.0/version: $VERSION/" bundle/manifests/lightspeed-operator.clusterserviceversion.yaml
sed -i.bak "s/$REPLACE_OPERATOR_IMAGE/$OPERATOR_IMAGE/" bundle/manifests/lightspeed-operator.clusterserviceversion.yaml
sed -i.bak "s/$REPLACE_API_IMAGE/$API_IMAGE/" bundle/manifests/lightspeed-operator.clusterserviceversion.yaml
rm -rf bundle/manifests/lightspeed-operator.clusterserviceversion.yaml.bak
make bundle-build bundle-push VERSION=$VERSION

#opm render quay.io/example-inc/example-operator-bundle:v0.1.0 --output=yaml >> lightspeed-catalog/operator.yaml



