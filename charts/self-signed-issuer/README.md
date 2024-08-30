# Self-Signed issuer

This Helm chart provides the self-signed cert-manager documentation setup: https://cert-manager.io/docs/configuration/selfsigned/

## Possible usages

- Create a global CA with cluster issuer(s) for applications on many namespaces;
- Create a global CA with issuer(s) for applications on the same namespace;
- And create scoped CA with issuers(s), for test purposes mostly.

## TODO

Leverage trust-manager to distribute a CA across various namespaces.
