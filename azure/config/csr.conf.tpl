[ req ]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
C = US
ST = California
L = Palo Alto
O = Anjuna Security
OU = Anjuna Security Dev
CN = ${APM_HOSTNAME}

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = ${APM_HOSTNAME}
