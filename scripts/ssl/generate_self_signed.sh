#!/bin/bash

# Configuration
DOMAIN="cloudtolocalllm.online"
CERT_DIR="/opt/cloudtolocalllm/ssl"
OPENSSL_CNF="/etc/ssl/openssl.cnf"

# Create certificate directory if it doesn't exist
mkdir -p "$CERT_DIR"

# Generate private key
openssl genrsa -out "$CERT_DIR/private.key" 2048

# Generate CSR
openssl req -new -key "$CERT_DIR/private.key" \
    -out "$CERT_DIR/certificate.csr" \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"

# Generate self-signed certificate
openssl x509 -req -days 365 \
    -in "$CERT_DIR/certificate.csr" \
    -signkey "$CERT_DIR/private.key" \
    -out "$CERT_DIR/certificate.crt"

# Set proper permissions
chmod 600 "$CERT_DIR/private.key"
chmod 644 "$CERT_DIR/certificate.crt"

echo "Self-signed certificate generated successfully!"
echo "Certificate location: $CERT_DIR/certificate.crt"
echo "Private key location: $CERT_DIR/private.key" 