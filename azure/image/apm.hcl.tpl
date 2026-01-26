disable_mlock = true
api_addr = "https://${APM_HOSTNAME}:${APM_PORT}"
plugin_directory = "/vault/plugins"

listener "tcp" {
  address = "0.0.0.0:${APM_PORT}"
  tls_cert_file = "/vault/tls/cert.pem"
  tls_key_file  = "/vault/tls/key.pem"
}

storage "azure" {
  accountName = "${APM_SA_NAME}"
  container = "vault"
  environment = "AzurePublicCloud"
  accountKey = "${APM_SAA_KEY}"
}
