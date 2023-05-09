authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${APM_HOSTNAME}
IP.1 = ${APM_IP_ADDRESS}
IP.2 = ${APM_PRIVATE_IP_ADDRESS}
