storage_source "file" {
address = "[::]:8201"
path    = "/vault/data"
}
storage_destination "consul" {
  path = "vault"
  address = "http://consul.openbluebridge.svc.cluster.local:8500"
}

cluster_addr = "[::]:8201"
