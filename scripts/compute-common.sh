#!/usr/bin/env bash
# Shared helpers for lab EC2 status/stop/start scripts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

compute_region() {
  if [[ -n "${AWS_REGION:-}" ]]; then
    echo "${AWS_REGION}"
    return
  fi
  if [[ -n "${AWS_DEFAULT_REGION:-}" ]]; then
    echo "${AWS_DEFAULT_REGION}"
    return
  fi
  if [[ -d "${REPO_ROOT}/.terraform" ]] || [[ -f "${REPO_ROOT}/terraform.tfstate" ]]; then
    local tf_region
    tf_region="$(
      terraform -chdir="${REPO_ROOT}" output -raw aws_region 2>/dev/null || true
    )"
    if [[ -n "${tf_region}" && "${tf_region}" != "null" ]]; then
      echo "${tf_region}"
      return
    fi
  fi
  echo "us-east-2"
}

AWS_REGION_RESOLVED="$(compute_region)"
export AWS_DEFAULT_REGION="${AWS_REGION_RESOLVED}"

require_aws() {
  if ! command -v aws >/dev/null 2>&1; then
    echo "aws CLI is required" >&2
    exit 1
  fi
}

lab_vpc_ids() {
  aws ec2 describe-vpcs \
    --region "${AWS_REGION_RESOLVED}" \
    --filters "Name=tag:Name,Values=operator_vpc" \
    --query 'Vpcs[].VpcId' \
    --output text
}

# Prints instance IDs, one per line.
lab_instance_ids() {
  local vpcs
  vpcs="$(lab_vpc_ids | xargs | tr ' ' ',')"
  if [[ -z "${vpcs}" ]]; then
    return 0
  fi

  aws ec2 describe-instances \
    --region "${AWS_REGION_RESOLVED}" \
    --filters \
      "Name=vpc-id,Values=${vpcs}" \
      "Name=instance-state-name,Values=pending,running,shutting-down,stopping,stopped" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text | tr '\t' '\n' | awk 'NF'
}

print_compute_status() {
  local ids
  ids="$(lab_instance_ids)"
  echo "Region: ${AWS_REGION_RESOLVED}"
  if [[ -z "${ids}" ]]; then
    echo "No lab EC2 instances found (VPC tag Name=operator_vpc)."
    return 0
  fi

  aws ec2 describe-instances \
    --region "${AWS_REGION_RESOLVED}" \
    --instance-ids ${ids} \
    --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,InstanceId:InstanceId,Type:InstanceType,State:State.Name,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress}' \
    --output table
}

wait_for_instances() {
  local action="$1"
  shift
  local ids=("$@")
  if [[ "${#ids[@]}" -eq 0 ]]; then
    return 0
  fi
  echo "Waiting for instances to ${action}..."
  aws ec2 "wait" "instance-${action}" \
    --region "${AWS_REGION_RESOLVED}" \
    --instance-ids "${ids[@]}"
}
