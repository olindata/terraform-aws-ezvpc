AWS ezVPC Terraform module - 
========================

Based on: [terraform-aws-vpc](https://github.com/terraform-aws-modules/terraform-aws-vpc) @ [1.18.0](https://github.com/terraform-aws-modules/terraform-aws-vpc/releases/tag/v1.18.0)

Terraform module for dummies which creates a VPC on AWS automatically, no effort required.

Usage
-----

```hcl
provider "aws" {
  version = "~> 1.0.0"
  region  = "eu-west-1"
}

module "vpc" {
  source = "olindata/vpc/aws"   # Use: github.com/olindata/terraform-aws-vpc.git for github

  name               = "my-vpc"
  cidr               = "10.0.0.0/16"
  number_of_azs      = "2"  # Change this to 3 or 4 and watch it work!
  enable_nat_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}
```

This module has everything our parent has making this a familiar and simple adoption.  Plus it has...

* **Automatic Subnetting + CIDR Calculation + Standardized Subnetting**
* **Automatic Availability Zone Selection, based on the number of AZs you choose and the AZs available in the region**
* **Removal of resource-specific tag naming, in favor of standardizing resource tagging**
* **Removal of nearly-unused Database/Elasticache/Redshift network resources**

Please see the [parent module](https://github.com/terraform-aws-modules/terraform-aws-vpc) for further documentation.  All inputs/outputs and elements of the parent module are relevant and applicable to this module except for variables relating to the database, elasticache, and redshift.  All have been removed.

Authors
-------

Forked from [github.com/terraform-aws-modules/terraform-aws-vpc](https://github.com/terraform-aws-modules/terraform-aws-vpc)
<br/>Module created and managed by [Farley](https://github.com/andrewfarley) and [OlinData](https://olindata.com/)

License
-------

Apache 2 Licensed. See LICENSE for full details.
