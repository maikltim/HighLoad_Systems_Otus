path "otus/data/otus-ro/*" {
  capabilities = ["read", "list"]
}

path "otus/data/otus-rw/*" {
  capabilities = ["read", "update", "create", "list"]
}
