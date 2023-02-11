#!/bin/bash
function usage {
  echo ""
  echo "Usage: $0"
  echo ""
  echo "This script related on cfn-lint to be installed."
  echo ""
  echo "cfn-lint: https://github.com/aws-cloudformation/cfn-python-lint"
  echo ""
  exit 1
}

PARENTDIR=$(pwd)

set -e

while getopts "h" opt; do
  case $opt in
    h)
      usage
      ;;
    \?)
      log_error "Unknown Option: -${OPTARG}"
      usage
      ;;
    :)
      log_error "Missing option argument for -${OPTARG}"
      usage
      ;;
    *)
      log_error "Invalid option: -${OPTARG}"
      usage
      ;;
  esac
done

if ! command -v cfn-lint >/dev/null
then
  log_error "Please install cfn-lint"
  usage
fi

# To make this easy we look for Cloudformation Templates by a naming convention of (*.cfn.yaml)
# Use this approach to solve if there are spaces in the paths (common for Windows users)
echo "Validating CloudFormation templates..."
find "${PARENTDIR}/stacks" -name '*.cfn.yaml' -print0 | sort -z | while IFS= read -r -d '' template;
do
  echo "Validating: ${template#$PARENTDIR}"
  if ! errors=$(cfn-lint "${template}" 2>&1)
  then
    echo "[fail](cfn-lint): ${template}: ${errors}"
    exit 1
  fi
done
