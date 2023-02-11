# WriteThis Infrastructure
The infrastructure for Write This project

This software is required to run the scripts in a bash environment.

* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv1.html)
* [cfn-lint](https://github.com/aws-cloudformation/cfn-python-lint)

You are also required to setup an [AWS Named Profile](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html).

## Cloudformation
We use Cloudformation (yaml format) for our 'infrastructure as code' approach. There is no need at this time to introduce any other 3rd party tools to learn. If we decide to go to another cloud provider Cloudformation is just a minor part of this application.

* [AWS Cloudformation](https://docs.aws.amazon.com/cloudformation/index.html)

Furthermore Cloudformation is fairly safe with its ability to detect errors and rollback changes to a known working state. However, you do need to pay attention to the documentation as some changes will remove resources and re-create them which may potentially loose data.

## Conventions
Each Cloudformation script will have the suffix of .cfn.yaml. This is really the only requirement other than the name should be descriptive of what the script is providing.

Comment the code. This is one of the advantages of using yaml as it supports comments in the file. Make sure you add comments, change comments, remove comments.


## Workflow
A general flow would be to add/modify cfn.yaml files. Then run the [validate-templates.sh](scripts/validate-templates.sh).

```bash
prompt> build-tools/validate-templates.sh
```

Any errors should be addressed before creating a pull request.

You are assumed to have setup a AWS profile and you are using it in your shell. These scripts will pick this up and report to you what account you are using. You will need to answer yes/no when prompted.

```bash
prompt> scripts/deploy-stacks.sh -a (dev|prod) -p <profile_name> -r <REGEX_FOR_TEMPLATES_FILTERING>
```

Cloudformation is pretty safe. If there is an error it will roll back the changes to a working state. There is an edge case. That case is if the top level stack as not yet been created. It may not be obvious but there is nothing for Cloudformation to rollback too in this case. Thus if there are errors during this first 'creation' then it is highly likely you will have to delete the top-level stack and try again after the failure has been addressed.

## General Structure
In general all stacks are in the stacks folder. Any build tools or scripts are located in the scripts folder. Stacks are given a NNN- prefix just to help with the order of creation. This happens when one stack needs to import from another stack.

## CodeBuild Local testing

Codebuild can be tested locally.

* Clone the AWS provided project for their Currated images.

```bash
git clone https://github.com/aws/aws-codebuild-docker-images
```

* Change Directory to the image that we use (currently it is aws/codebuild/standard:6.0) and build the image locally. This will take a while as the AWS images are rather large.

```bash
cd ubuntu/standard/6.0
docker build --pull --tag aws/codebuild/standard:6.0 --rm --file Dockerfile .
```

* Now use the script provided in this same repository called codebuild_build.sh, lcated in local_builds, to build any buildspec in any of the repositories.

```bash
codebuild_build.sh -a artifact -i aws/codebuild/standard:6.0 -c -p <AWS Profile to use> -b <the buildspec to use>
```

# Cleanup AWS account
We need remove some resources manually after removing CloudFormation stacks
- *S3 buckets*
- *CloudWatch logs*