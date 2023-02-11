#!/bin/bash

# We want this script to exit if any command fails.
set -e

# function for print usage
function usage () {
	cat << EOF

 ***********************   USAGE   ***********************
`basename $0` [-h] [-p AWS_PROFILE_NAME] [-r REGEX] [-d AWS_DEFAULT_REGION]

Example:
`basename $0` -p namewritethis -r '002-some-template-name\.cfn\.yaml'

Optional arguments:
  -h, --help            show this message and exit
  -r REGEX              apply templates inside repository which match regex only (like -r ^...-.*\.cfn\.yaml$)
  -s                    option for silent run (for using inside codepipeline)

Non-optional arguments:
  -a ACCOUNT_TYPE       the AWS account type to use dev|prod. (like -p dev)
  -p AWS_PROFILE_NAME   the AWS CLI Profile to use. (like -p namewritethis)
                        See: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html
  -d AWS_DEFAULT_REGION if defined, this environment variable overrides the value for the profile setting region

This script relies on the aws cli to be installed.

aws cli: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv1.html

Also make sure your default credentials point to the correct profile. This script will use your defaults
in .aws/config

 *********************************************************
EOF

  exit 1

}

PROFILE_FLAG=false
ACCOUNT_TYPE_FLAG=false
REGION_FLAG=false
SILENT_MODE=false
REGEX_FLAG=false
REGEX='.*\.cfn\.yaml'

while getopts "a:p:d:r:hsm" opt; do
  case $opt in
    a)
       ACCOUNT_TYPE=${OPTARG}
       ACCOUNT_TYPE_FLAG=true
       ;;
    p)
      PROFILE_FLAG=true
      PROFILE=${OPTARG}
      ;;
    r)
      REGEX_FLAG=true
      REGEX=${OPTARG}
      ;;
    d)
      REGION_FLAG=true;region=${OPTARG}
      ;;
    s)
      SILENT_MODE=true
      ;;
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

if ! ${ACCOUNT_TYPE_FLAG}; then
  log_error "The account type must be provided"
  usage
fi

if ! command -v aws > /dev/null ; then
  echo "ERROR: Please install the aws cli"
  usage
fi

if ${PROFILE_FLAG}; then
  export AWS_PROFILE="${PROFILE}"
  echo -e "Using AWS_PROFILE - ${AWS_PROFILE}\n"
elif ! ${SILENT_MODE}; then
  echo "[ERROR] You didn't set AWS_PROFILE parameter '-p'"
  usage
fi

if ${REGION_FLAG}
then
  export AWS_DEFAULT_REGION="${region}"
  echo "Using AWS_DEFAULT_REGION (${AWS_DEFAULT_REGION})"
fi

cd "stacks/" || exit 1

user_id=$(aws sts get-caller-identity --query 'UserId' --output text)
account_id=$(aws sts get-caller-identity --query 'Account' --output text)
aws_user=$(aws sts get-caller-identity --query 'Arn' --output text)
account_alias=$(aws iam list-account-aliases --query 'AccountAliases[0]' --output text)

[[ ${REGEX_FLAG} ]] && echo "Will be using the next REGEX to find templates inside repository: ${REGEX}"

cfn_list=$(ls | grep "${REGEX}" | tr -d '\0')

cat << EOF

    ######## WARNING ########

Please review this information and make sure
it is accurate. This is the information that
will be used to deploy these templates.

Account type:   ${ACCOUNT_TYPE}
Account Id:     ${account_id}
Account Alias:  ${account_alias}
Account User:   ${aws_user}
User ID:        ${user_id}

By continuing you will be using this
information to deploy infrastructructure

The next list of CFN's will be applied:
${cfn_list}

    ##########################

EOF

if ! ${SILENT_MODE}; then
  while true; do
    read -p "Are you sure you want to continue (Y/N)? " -n 1 -r
    case $REPLY in
      [Yy])
        echo ""
        break
        ;;
      [Nn])
        echo ""
        echo "Wise choice. Make sure you know what you are doing first!"
        exit 1
        ;;
      *)
        echo ""
        echo "Please answer yes (Yy) or no (Nn)"
        ;;
    esac
  done
fi

for template in ${cfn_list}; do
  stackname="$(basename "${template}" .cfn.yaml | cut -d'-' -f2-)-${ACCOUNT_TYPE}"
  echo "Deploying stack ${stackname}"

    aws cloudformation deploy \
      --template-file "${template}" \
      --stack-name "${stackname}" \
      --parameter-overrides AccountType="${ACCOUNT_TYPE}" \
      --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND\
      --s3-prefix "cloudformation/${ACCOUNT_TYPE}/environments" \
      --no-fail-on-empty-changeset >/dev/null
done

cd ..