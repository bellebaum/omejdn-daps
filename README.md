# Omejdn Configuration for the DAPS use case

This repository contains the necessary configuration templates to use an Omejdn instance as a DAPS as described in [IDS-G](https://github.com/International-Data-Spaces-Association/IDS-G).
This document lists the necessary steps to adapt them to your use case.

## Important Considerations

A Dynamic Attribute Provisioning System (DAPS) has the intent to assertain certain attributes to organizations and connectors.
Hence, third parties do not need to trust the latter **provided they trust the DAPS assertions**.
This is usually a matter of configuration on the verifying party's end which is not part of this document.
In general, it requires registering both the DAPS certificate and its name as a trusted identity.

**This document builds a DAPS for testing purposes only**

## Requirements

- [Omejdn Server](https://github.com/Fraunhofer-AISEC/omejdn-server)'s dependencies
- [OpenSSL](https://www.openssl.org/)

This repository has submodules.
Make sure to download them using `git submodule update --init`

## Minimal Configuration

The configuration consists of the following steps:

1. Generating a DAPS secret key and certificate
1. Provisioning the provided config files and registering connectors
1. Starting the server

All commands are to be run from the repository's root directory

### DAPS Key Generation

First, you need to generate a signing key for Omejdn.
This can be done using openssl and the following command.
It is recommended to fill out the form, but not strictly necessary for test setups.

```
$ openssl req -newkey rsa:2048 -new -nodes -x509 -days 3650 -keyout daps.key -out daps.cert
```

This will create two files:

* `daps.key` is the private signing key. It should **never** be known to anyone but the server, since anyone with this file can issue arbitrary DATs.
* `daps.cert` is the certificate file. It is not confidential and is necessary to validate DATs. It must be made available to any DAT verifying entity.

### Config Files

#### Server config

Open the provided `config/omejdn.yml` and replace every occurence of `http://daps.example.com` with your server's URI.

#### Registering Connectors

Connectors can be registered at any point by adding clients to the `config/clients.yml` file and placing the certificate in the right place.
To ease this process, use the provided script `scripts/register_connector.sh`

Usage:

```
$ scripts/register_connector.sh NAME SECURITY_PROFILE CERTIFICATE_FILE >> config/clients.yml
```

The `SECURITY_PROFILE` and `CERTIFICATE` arguments are optional. Values for the former include:

- idsc:BASE_SECURITY_PROFILE (default)
- idsc:TRUST_SECURITY_PROFILE
- idsc:TRUST_PLUS_SECURITY_PROFILE

The script will automatically generate new client certificates (`keys/NAME.cert`) and keys (`keys/NAME.key`) if you do not provide a certificate manually.


### Starting Omejdn

Replace the `keys` and `config` folder inside `omejdn-server` by the ones in this folder.

Navigate into `omejdn-server`
Now you may start Omejdn by executing

```
$ bundle install
$ ruby omejdn.rb
```

The endpoint for issuing DATs is `/token`. You may use it as described in [IDS-G](https://github.com/International-Data-Spaces-Association/IDS-G).

## Going Forward

While the above configuration should be sufficient for testing purposes,
you probably want to consider the following ideas in the long term:

#### Transport Encryption

Run Omejdn behind a Proxy with https support, such as [Nginx](https://nginx.org/en/).
Do not forget to edit `config/omejdn.yml` to reflect the new address.

#### Certificate Authorities

As described in this document, all certificates are self-signed.
Depending on your use-case, you may want to use certificates issued by trusted Certificate Authorities for both the DAPS and the Connectors.

#### Omejdn Config API

If you do not have Access to the DAPS or want to edit connectors (=clients) and configuration remotely,
you may enable Omejdn's Config API.

To use it, uncomment the relevant lines (remove the # symbol) in `config/scope_mapping.yml`,
then edit or register a client with an attribute like this:

```
- key: omejdn
- value: admin
```

Add the scope `omejdn:admin` to its list of allowed scopes.

This client may now use the Omejdn Config API as documented [here](https://github.com/Fraunhofer-AISEC/omejdn-server/blob/master/API.md).
