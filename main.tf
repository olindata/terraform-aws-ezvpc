terraform {
  required_version = ">= 0.11.1" # introduction of Local Values configuration language feature
}

# This is our input (instead of asking the user) to get the AZ's available in this region
data "aws_availability_zones" "azs" {}

# This gets our AWS Account ID
data "aws_caller_identity" "current" {}

# These are new local variables we are extracting from the user's variable inputs
locals {
  azs = "${slice(data.aws_availability_zones.azs.names, 0, var.number_of_azs)}" # This is pulled from the AZs data source
}

######
# VPC
######
resource "aws_vpc" "this" {
  cidr_block           = "${var.cidr}"
  instance_tenancy     = "${var.instance_tenancy}"
  enable_dns_hostnames = "${var.enable_dns_hostnames}"
  enable_dns_support   = "${var.enable_dns_support}"

  tags = "${merge(var.tags, map("Name", format("%s", var.name)))}"
}

###################
# DHCP Options Set
###################
resource "aws_vpc_dhcp_options" "this" {
  count = "${var.enable_dhcp_options ? 1 : 0}"

  domain_name          = "${var.dhcp_options_domain_name}"
  domain_name_servers  = "${var.dhcp_options_domain_name_servers}"
  ntp_servers          = "${var.dhcp_options_ntp_servers}"
  netbios_name_servers = "${var.dhcp_options_netbios_name_servers}"
  netbios_node_type    = "${var.dhcp_options_netbios_node_type}"

  tags = "${merge(var.tags, map("Name", format("%s", var.name)))}"
}

###############################
# DHCP Options Set Association
###############################
resource "aws_vpc_dhcp_options_association" "this" {
  count = "${var.enable_dhcp_options ? 1 : 0}"

  vpc_id          = "${aws_vpc.this.id}"
  dhcp_options_id = "${aws_vpc_dhcp_options.this.id}"
}

###################
# Internet Gateway
###################
resource "aws_internet_gateway" "this" {
  count  = 1
  vpc_id = "${aws_vpc.this.id}"

  tags = "${merge(var.tags, map("Name", format("%s", var.name)))}"
}

################
# Publiс routes
################
resource "aws_route_table" "public" {
  count            = 1
  vpc_id           = "${aws_vpc.this.id}"
  propagating_vgws = ["${var.public_propagating_vgws}"]

  tags = "${merge(var.tags, map("Name", format("%s-public", var.name)))}"
}

resource "aws_route" "public_internet_gateway" {
  count                  = 1
  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.this.id}"
}

#################
# Private routes
# There are so many route-tables as the largest amount of subnets of each type (really?)
#################
resource "aws_route_table" "private" {
  count = "${var.number_of_azs}"

  vpc_id           = "${aws_vpc.this.id}"
  propagating_vgws = ["${var.private_propagating_vgws}"]

  tags = "${merge(var.tags, map("Name", format("%s-private-%s", var.name, element(local.azs, count.index))))}"

  lifecycle {
    # When attaching VPN gateways it is common to define aws_vpn_gateway_route_propagation
    # resources that manipulate the attributes of the routing table (typically for the private subnets)
    ignore_changes = ["propagating_vgws"]
  }
}

################
# Public subnet
################
resource "aws_subnet" "public" {
  count = "${var.number_of_azs}"

  vpc_id                  = "${aws_vpc.this.id}"
  cidr_block              = "${cidrsubnet(var.cidr, lookup(var.cidr_addition_map, var.number_of_azs), count.index + var.number_of_azs)}"
  availability_zone       = "${element(local.azs, count.index)}"
  map_public_ip_on_launch = "${var.map_public_ip_on_launch}"

  tags = "${merge(var.tags, map("Name", format("%s-public-%s", var.name, element(local.azs, count.index))), var.public_subnet_tags)}"
}

#################
# Private subnet
#################
resource "aws_subnet" "private" {
  count = "${var.number_of_azs}"

  vpc_id            = "${aws_vpc.this.id}"
  cidr_block        = "${cidrsubnet(var.cidr, lookup(var.cidr_addition_map, var.number_of_azs), count.index)}"
  availability_zone = "${element(local.azs, count.index)}"

  tags = "${merge(var.tags, map("Name", format("%s-private-%s", var.name, element(local.azs, count.index))), var.private_subnet_tags)}"
}

##############
# NAT Gateway
##############
# Workaround for interpolation not being able to "short-circuit" the evaluation of the conditional branch that doesn't end up being used
# Source: https://github.com/hashicorp/terraform/issues/11566#issuecomment-289417805
#
# The logical expression would be
#
#    nat_gateway_ips = var.reuse_nat_ips ? var.external_nat_ip_ids : aws_eip.nat.*.id
#
# but then when count of aws_eip.nat.*.id is zero, this would throw a resource not found error on aws_eip.nat.*.id.
locals {
  nat_gateway_ips = "${split(",", (var.reuse_nat_ips ? join(",", var.external_nat_ip_ids) : join(",", aws_eip.nat.*.id)))}"
}

resource "aws_eip" "nat" {
  count = "${(var.enable_nat_gateway && !var.reuse_nat_ips) ? (var.single_nat_gateway ? 1 : length(local.azs)) : 0}"

  vpc = true

  tags = "${merge(var.tags, map("Name", format("%s-%s", var.name, element(local.azs, (var.single_nat_gateway ? 0 : count.index)))))}"
}

resource "aws_nat_gateway" "this" {
  count = "${var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(local.azs)) : 0}"

  allocation_id = "${element(local.nat_gateway_ips, (var.single_nat_gateway ? 0 : count.index))}"
  subnet_id     = "${element(aws_subnet.public.*.id, (var.single_nat_gateway ? 0 : count.index))}"

  tags = "${merge(var.tags, map("Name", format("%s-%s", var.name, element(local.azs, (var.single_nat_gateway ? 0 : count.index)))))}"

  depends_on = ["aws_internet_gateway.this"]
}

resource "aws_route" "private_nat_gateway" {
  count = "${var.enable_nat_gateway ? var.number_of_azs : 0}"

  route_table_id         = "${element(aws_route_table.private.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${element(aws_nat_gateway.this.*.id, count.index)}"
}

######################
# VPC Endpoint for S3
######################
data "aws_vpc_endpoint_service" "s3" {
  count = "${var.enable_s3_endpoint}"

  service = "s3"
}

resource "aws_vpc_endpoint" "s3" {
  count = "${var.enable_s3_endpoint}"

  vpc_id       = "${aws_vpc.this.id}"
  service_name = "${data.aws_vpc_endpoint_service.s3.service_name}"
}

resource "aws_vpc_endpoint_route_table_association" "private_s3" {
  count = "${var.enable_s3_endpoint ? var.number_of_azs : 0}"

  vpc_endpoint_id = "${aws_vpc_endpoint.s3.id}"
  route_table_id  = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_vpc_endpoint_route_table_association" "public_s3" {
  count = "${var.enable_s3_endpoint ? var.number_of_azs : 0}"

  vpc_endpoint_id = "${aws_vpc_endpoint.s3.id}"
  route_table_id  = "${aws_route_table.public.id}"
}

############################
# VPC Endpoint for DynamoDB
############################
data "aws_vpc_endpoint_service" "dynamodb" {
  count = "${var.enable_dynamodb_endpoint}"

  service = "dynamodb"
}

resource "aws_vpc_endpoint" "dynamodb" {
  count = "${var.enable_dynamodb_endpoint}"

  vpc_id       = "${aws_vpc.this.id}"
  service_name = "${data.aws_vpc_endpoint_service.dynamodb.service_name}"
}

resource "aws_vpc_endpoint_route_table_association" "private_dynamodb" {
  count = "${var.enable_dynamodb_endpoint ? var.number_of_azs : 0}"

  vpc_endpoint_id = "${aws_vpc_endpoint.dynamodb.id}"
  route_table_id  = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_vpc_endpoint_route_table_association" "public_dynamodb" {
  count = "${var.enable_dynamodb_endpoint ? var.number_of_azs : 0}"

  vpc_endpoint_id = "${aws_vpc_endpoint.dynamodb.id}"
  route_table_id  = "${aws_route_table.public.id}"
}

##########################
# Route table association
##########################
resource "aws_route_table_association" "private" {
  count = "${var.number_of_azs}"

  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_route_table_association" "public" {
  count = "${var.number_of_azs}"

  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

##############
# VPN Gateway
##############
resource "aws_vpn_gateway" "this" {
  count = "${var.enable_vpn_gateway ? 1 : 0}"

  vpc_id = "${aws_vpc.this.id}"

  tags = "${merge(var.tags, map("Name", format("%s", var.name)))}"
}
