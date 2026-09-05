# AWS S3 → Lambda → SNS Automation

Production-oriented Bash automation for provisioning AWS infrastructure and processing S3 events through SNS.

## Architecture

```text
S3 Bucket
    │
    │ Object Created
    ▼
Lambda
    │
    │ Publish
    ▼
SNS Topic
    │
    ▼
Subscribers
```

## Scripts

```text
├── infrastructure-provisioning.sh
├── sns-notification.sh
└── README.md
```

### `infrastructure-provisioning.sh`

Provisions and validates the AWS resources required by the workflow:

* IAM execution role
* Lambda execution policy
* SNS topic
* Resource tags
* AWS identity validation

Features:

* `set -Eeuo pipefail`
* Dependency validation
* Idempotent resource creation
* Error handling
* Environment-based configuration
* Resource verification
* Least-privilege-oriented IAM design

### `sns-notification.sh`

Processes an S3 event JSON file and publishes an SNS notification.

Features:

* S3 event parsing with `jq`
* AWS CLI automation
* Input validation
* Error handling
* Structured logging
* Environment-based SNS configuration

## Requirements

```bash
bash
aws
jq
```

Install dependencies on Ubuntu:

```bash
sudo apt update
sudo apt install -y awscli jq
```

Verify AWS authentication:

```bash
aws sts get-caller-identity
```

## Configuration

```bash
export AWS_REGION="us-east-1"
export IAM_ROLE_NAME="s3-lambda-sns"
export SNS_TOPIC_NAME="s3-lambda-sns"
export SNS_TOPIC_ARN="arn:aws:sns:us-east-1:123456789012:s3-lambda-sns"
```

Never hard-code AWS credentials or tokens in the scripts.

## Usage

Make scripts executable:

```bash
chmod +x infrastructure-provisioning.sh sns-notification.sh
```

Provision infrastructure:

```bash
./infrastructure-provisioning.sh
```

Process an S3 event:

```bash
./sns-notification.sh event.json
```

## Validation

Bash syntax:

```bash
bash -n infrastructure-provisioning.sh
bash -n sns-notification.sh
```

Static analysis:

```bash
shellcheck infrastructure-provisioning.sh
shellcheck sns-notification.sh
```

## DevOps Practices Demonstrated

* Bash automation
* AWS CLI
* IAM
* S3
* Lambda
* SNS
* `jq` JSON processing
* Idempotency
* Error handling
* Logging
* Environment variables
* Least-privilege IAM
* Resource tagging
* Infrastructure provisioning
* Event-driven automation
* CI/CD readiness

## Infrastructure vs Runtime

| Script                           | Purpose                                         |
| -------------------------------- | ----------------------------------------------- |
| `infrastructure-provisioning.sh` | Provision AWS infrastructure                    |
| `sns-notification.sh`            | Process S3 events and publish SNS notifications |

