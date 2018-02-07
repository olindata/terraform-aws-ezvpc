AWS ezVPC Terraform module - 
========================

Based on: [terraform-aws-vpc](https://github.com/terraform-aws-modules/terraform-aws-vpc)

Terraform module which creates VPC resources on AWS, but made EASIER.  The advantages this has is...

1. Automatic Subnetting + CIDR Calculation + Standardized Subnetting
1. Automatic Availability Zone Selection, based on the number of AZs you choose and the AZs available in the region
1. Removal of resource-specific tag naming, in favor of standardizing resource tagging
1. Removal of nearly-unused Database/Elasticache/Redshift network resources

All other resources and automation from the parent module are still supported in here, making this a familiar and simple adoption.

Usage
-----

```hcl
provider "aws" {
  version = "~> 1.0.0"
  region  = "eu-west-1"
}

module "vpc" {
  source = "github.com/olindata/terraform-aws-vpc.git?ref=master"

  name               = "my-vpc"
  cidr               = "10.0.0.0/16"
  number_of_azs      = "2"
  enable_nat_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}
```

Feel free to compare this to [our parent's usage example](https://github.com/terraform-aws-modules/terraform-aws-vpc#usage)

Please see the [parent module](https://github.com/terraform-aws-modules/terraform-aws-vpc) for further documentation.  All inputs/outputs and elements of the parent module are relevant and applicable to this module except for variables relating to the database, elasticache, and redshift.  All have been removed.

Authors
-------

Forked from [github.com/terraform-aws-modules/terraform-aws-vpc](https://github.com/terraform-aws-modules/terraform-aws-vpc)
<br/>Module managed by [Farley](https://github.com/andrewfarley).

License
-------

Apache 2 Licensed. See LICENSE for full details.
