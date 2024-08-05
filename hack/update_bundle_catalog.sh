# Helper tool to update the catalog artifacts and bundle artifacts
# These genereated artifacts are used to build the catalog image
# Pre-requisites: opm, make
# Usage: ./hack/update_bundle_catalog.sh

#!/bin/bash

set -euo pipefail

TEMP_BUNDLE_FILE="quay.io/redhat-user-workloads/crt-nshift-lightspeed-tenant/ols/bundle@sha256:b9387e5900e700db47d2b4d7f106b43d0958a3b0d3d4f4b68495141675b66a1c"
cleanup() {
  # remove temporary bundle file
  if [ -n "${TEMP_BUNDLE_FILE}" ]; then
    rm -f "${TEMP_BUNDLE_FILE}"
  fi

}

trap cleanup EXIT

: ${OPM:=$(command -v opm)}
echo "using opm from ${OPM}"
# check if opm version is v1.39.0 or exit
if ! ${OPM} version | grep -q "v1.27.1"; then
  echo "opm version v1.27.1 is required"
  exit 1
fi

: ${YQ:=$(command -v yq)}
echo "using yq from ${YQ}"
# check if yq exists
if [ -z "${YQ}" ]; then
  echo "yq is required"
  exit 1
fi

# Set the bundle version
: "${BUNDLE_TAG:=0.1.1}"

: "${OPERATOR_IMAGE:=registry.redhat.io/openshift-lightspeed-beta/lightspeed-rhel9-operator@sha256:049a1a398ed87e4f35c99b36304055c7f75d0188a4d8c1726df59b5f400561e5}"
: "${BUNDLE_IMAGE:=registry.redhat.io/openshift-lightspeed-beta/lightspeed-operator-bundle@sha256:b9387e5900e700db47d2b4d7f106b43d0958a3b0d3d4f4b68495141675b66a1c}"
: "${CONSOLE_IMAGE:=registry.redhat.io/openshift-lightspeed-beta/lightspeed-console-plugin-rhel9@sha256:4f45c9ba068cf92e592bb3a502764ce6bc93cd154d081fa49d05cb040885155b}"

: "${CATALOG_FILE:=lightspeed-catalog/index.yaml}"
CATALOG_INITIAL_FILE="hack/operator.yaml"
CSV_FILE="bundle/manifests/lightspeed-operator.clusterserviceversion.yaml"

BUNDLE_DOCKERFILE="bundle.Dockerfile"

# if RELATED_IMAGES is not defined, extract related images or use default values
: "${RELATED_IMAGES:=$(${YQ} ' .spec.relatedImages' -ojson ${CSV_FILE})}"
if [ -z "${RELATED_IMAGES}" ]; then
  RELATED_IMAGES=$(
    cat <<-EOF
[
  {
    "name": "lightspeed-service-api",
    "image": "${SERVICE_IMAGE}"
  },
  {
    "name": "lightspeed-console-plugin",
    "image": "${CONSOLE_IMAGE}"
  },
  {
    "name": "lightspeed-operator",
    "image": "${OPERATOR_IMAGE}"
  }
]
EOF
  )
fi

# Build the bundle image
echo "Updating bundle artifacts for image ${OPERATOR_IMAGE}"
rm -rf ./bundle
make bundle VERSION="${BUNDLE_TAG}" IMG="${OPERATOR_IMAGE}"
# restore related images to the CSV file
${YQ} eval -i '.spec.relatedImages='"${RELATED_IMAGES}" ${CSV_FILE}

# use UBI image as base image for bundle image
: "${BASE_IMAGE:=registry.access.redhat.com/ubi9/ubi-minimal@sha256:104cf11d890aeb7dd5728b7d7732e175a0e4018f1bb00d2faebcc8f6bf29bd52}"
sed -i 's|^FROM scratch|FROM '"${BASE_IMAGE}"'|' ${BUNDLE_DOCKERFILE}

# make bundle image comply with enterprise contract requirements
cat <<EOF >>${BUNDLE_DOCKERFILE}

# licenses required by Red Hat certification policy
# refer to https://docs.redhat.com/en/documentation/red_hat_software_certification/2024/html-single/red_hat_openshift_software_certification_policy_guide/index#con-image-content-requirements_openshift-sw-cert-policy-container-images
COPY LICENSE /licenses/

# Labels for enterprise contract
LABEL com.redhat.component=openshift-lightspeed
LABEL description="Red Hat OpenShift Lightspeed - AI assistant for managing OpenShift clusters."
LABEL distribution-scope=public
LABEL io.k8s.description="Red Hat OpenShift Lightspeed - AI assistant for managing OpenShift clusters."
LABEL io.k8s.display-name="Openshift Lightspeed"
LABEL io.openshift.tags="openshift,lightspeed,ai,assistant"
LABEL name=openshift-lightspeed
LABEL release=${BUNDLE_TAG}
LABEL url="https://github.com/openshift/lightspeed-operator"
LABEL vendor="Red Hat, Inc."
LABEL version=${BUNDLE_TAG}
LABEL summary="Red Hat OpenShift Lightspeed"

# Set user to non-root for security reasons.
USER 1001
EOF

echo "Adding bundle image to FBC using image ${BUNDLE_IMAGE}"
#Initialize lightspeed-catalog/index.yaml from hack/operator.yaml
cat "${CATALOG_INITIAL_FILE}" >"${CATALOG_FILE}"

# This bundle image is used to build the catalog image
# Give it a reference in a writable image registry
TEMP_BUNDLE_IMG=${TEMP_BUNDLE_IMG:-}
if [ -z "${TEMP_BUNDLE_IMG}" ]; then
  TEMP_BUNDLE_IMG="quay.io/redhat-user-workloads/crt-nshift-lightspeed-tenant/ols/bundle@sha256:b9387e5900e700db47d2b4d7f106b43d0958a3b0d3d4f4b68495141675b66a1c"
  echo "No TEMP_BUNDLE_IMG specified. Catalog is built using default bundle image ${TEMP_BUNDLE_IMG}"
  echo "If you have changed the CRD, please specifiy TEMP_BUNDLE_IMG to your writable image registry and re-run the script"
fi

# create a temporary file for the bundle part of the catalog
TEMP_BUNDLE_FILE=$(mktemp)

${OPM} render "${TEMP_BUNDLE_IMG}" --output=yaml >"${TEMP_BUNDLE_FILE}"
# restore bundle image to the catalog file
${YQ} eval -i '.image='"\"${BUNDLE_IMAGE}\"" ${TEMP_BUNDLE_FILE}
# restore bundle related images and the bundle itself to the catalog file
${YQ} eval -i '.relatedImages='"${RELATED_IMAGES}" ${TEMP_BUNDLE_FILE}
${YQ} eval -i '.relatedImages += [{"name": "lightspeed-operator-bundle", "image": "'"${BUNDLE_IMAGE}"'"}]' ${TEMP_BUNDLE_FILE}

cat ${TEMP_BUNDLE_FILE} >>${CATALOG_FILE}

cat <<EOF >>"${CATALOG_FILE}"
---
schema: olm.channel
package: lightspeed-operator
name: preview
entries:
  - name: lightspeed-operator.v${BUNDLE_TAG}
EOF

${OPM} validate $(dirname "${CATALOG_FILE}")
if [ $? -ne 0 ]; then
  echo "Validation failed for ${CATALOG_FILE}"
  exit 1
else
  echo "Validation passed for ${CATALOG_FILE}"
fi

echo "Finished running $(basename "$0")"
