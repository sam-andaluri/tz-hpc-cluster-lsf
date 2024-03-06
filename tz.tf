
resource "ibm_cis_dns_record" "appcenter_a_record" {
  cis_id  = var.cis_crn
  domain_id = var.cis_domain_id
  name    = "appcenter-${var.cluster_prefix}"
  type    = "A"
  content = ibm_is_floating_ip.appcenter_fip.address
  ttl     = 900
}

resource "ibm_is_floating_ip" "appcenter_fip" {
  name           = "${var.cluster_prefix}-appcenter-fip"
  target         = ibm_is_instance.management_host.primary_network_interface[0].id
  resource_group = data.ibm_resource_group.rg.id
  tags           = local.tags

  lifecycle {
    ignore_changes = [resource_group]
  }
}

resource "ibm_is_security_group_rule" "ingress_tcp" {
  group     = ibm_is_security_group.sg.id
  direction = "inbound"
  remote    = var.remote_allowed_ips[count.index]

  tcp {
    port_min = 8080
    port_max = 8080
  }
}
