# TLS example server

Contained in this directory is an `nginx` config and certificate/key files
for to run the SSL/TLS examples.  They were generated using [easy-rsa](https://github.com/OpenVPN/easy-rsa),
which allows you to create your own Certificate Authority (CA).  The private
key and the CA are public, and should in no way ever be used for real
production configurations!

They keys and certificates were created with these commands:

 ./easyrsa init-pki
 ./easyrsa build-ca
 ./easyrsa build-server-full localhost
 ./easyrsa build-client-full client

The password for the client key is simply `password`.
