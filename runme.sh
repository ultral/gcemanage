#!/bin/bash
set -e

PLAN_DIR="envs/gce"
PROJECT_ID=$(tr -d " \t" < "${PLAN_DIR}/config_backend.tfvars"| grep "^project=" | cut -f 2 -d "=" | tr -d "\n\r\"")
BUCKET_NAME=$(tr -d " \t" < "${PLAN_DIR}/config_backend.tfvars"| grep "^bucket=" | cut -f 2 -d "=" | tr -d "\n\r\"")

usage () {
  echo "Usage: $0 [--gcloud-init] [--terraform-apply] [--terraform-destroy][--help] [--project-id <some-name>]"
  echo ""
}

gcloud_setup () {
  local PROJECT_NAME
  local BILLING_ID
  local BUCKET_NAME
  local CRED_URL
  PROJECT_NAME="$1"
  BUCKET_NAME="$2"
  CRED_URL="https://console.developers.google.com/apis/credentials?project=${PROJECT_NAME}"

  echo "Project: ${PROJECT_NAME}"
  echo "Bucket:  ${BUCKET_NAME}"

  gcloud init --project "${PROJECT_NAME}"
  echo ""
  echo "!!!!!!!!!!!!!!!!!!!!!!!"
  echo ""
  echo "Please visit: ${CRED_URL} and save key as 'envs/gce/.key.json'"
  echo "${CRED_URL}"
  echo ""
  echo "!!!!!!!!!!!!!!!!!!!!!!!"
  echo ""
  echo "After that press Enter"
  read

  BILLING_ID=$(gcloud alpha billing accounts list |grep True|head -n1|cut -f1 -d" ")
  echo "Please check your billing ID '${BILLING_ID}'"
  echo "After that press Enter"
  read

  gcloud alpha billing projects link "${PROJECT_NAME}" --billing-account "${BILLING_ID}"
  #gcloud services enable container.googleapis.com
  gcloud services enable storage-api.googleapis.com
  gcloud services enable storage-component.googleapis.com
  gsutil mb -p "${PROJECT_NAME}" "gs://${BUCKET_NAME}/"
}

terraform_run () {
  local PLAN_DIR
  local GOOGLE_CREDS
  PLAN_DIR="$1"
  GOOGLE_CREDS=$(cat "${PLAN_DIR}/.key.json")

  echo "Run terraform from '${PLAN_DIR}'"

  GOOGLE_CREDENTIALS="${GOOGLE_CREDS}" terraform init \
    -backend-config="${PLAN_DIR}/config_backend.tfvars" \
    "${PLAN_DIR}"
  GOOGLE_CREDENTIALS="${GOOGLE_CREDS}" terraform plan \
    -var-file="${PLAN_DIR}/config_secrets.tfvars" \
    -var-file="${PLAN_DIR}/config_backend.tfvars" \
    "${PLAN_DIR}"
  GOOGLE_CREDENTIALS="${GOOGLE_CREDS}" terraform apply \
    -var-file="${PLAN_DIR}/config_secrets.tfvars" \
    -var-file="${PLAN_DIR}/config_backend.tfvars" \
    "${PLAN_DIR}"
}

terraform_destroy () {
  local PLAN_DIR
  local GOOGLE_CREDS
  PLAN_DIR="$1"
  GOOGLE_CREDS=$(cat "${PLAN_DIR}/.key.json")

  GOOGLE_CREDENTIALS="${GOOGLE_CREDS}" terraform destroy  \
    -var-file="${PLAN_DIR}/config_secrets.tfvars" \
    -var-file="${PLAN_DIR}/config_backend.tfvars" \
    "${PLAN_DIR}"
}


while [ "$1" != "" ] ; do
  case "$1" in
    -g|--gcloud-init) GCLOUD_INIT='YES' ;;
    -t|--terraform-apply) TERRAFORM_APPLY='YES' ;;
    -d|--terraform-destroy) TERRAFORM_DESTROY='YES' ;;
    -h|--help) usage ;;
  esac
  shift
done

[ -z "${GCLOUD_INIT}" ] && GCLOUD_INIT='NO'
[ -z "${TERRAFORM_APPLY}" ] && TERRAFORM_APPLY='NO'
[ -z "${TERRAFORM_DESTROY}" ] && TERRAFORM_DESTROY='NO'

[ "_${GCLOUD_INIT}" = "_YES" ] && gcloud_setup "${PROJECT_ID}" "${BUCKET_NAME}"
[ "_${TERRAFORM_APPLY}" = "_YES" ] && terraform_run "${PLAN_DIR}"
[ "_${TERRAFORM_DESTROY}" = "_YES" ] && terraform_destroy "${PLAN_DIR}"
