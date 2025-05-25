# Deployment Guide

## Overview

This guide outlines the deployment process for the CloudToLocalLLM application.

## Prerequisites

*   Docker and Docker Compose installed on the server
*   Git installed on the server
*   Domain name pointing to the server
*   SSL certificates (self-signed or Let's Encrypt)

## Deployment Steps

1.  Clone the repository:
    ```bash
    git clone https://github.com/yourusername/CloudToLocalLLM.git
    cd CloudToLocalLLM
    ```

2.  Configure environment variables:
    *   Copy `.env.example` to `.env`
    *   Update the values in `.env` with your configuration

3.  Start the services:
    ```bash
    docker compose -f config/docker/docker-compose.yml up -d
    ```

## Service Management

### Available Services

*   `cloudtolocalllm-webapp`: Main web application
*   `cloud`: Cloud service for handling cloud operations

### Common Commands

*   `docker compose ps` to list running services
*   `docker compose logs <service_name>` to view logs
*   `docker compose restart <service_name>` to restart a service
*   `docker compose down` to stop all services

## SSL Configuration

The application uses Let's Encrypt certificates for secure HTTPS connections.

### Let's Encrypt Certificates

The application automatically manages Let's Encrypt certificates through the certbot service.

2.  The certificates will be automatically mounted into the webapp container.

### Let's Encrypt Certificates

1.  Install certbot:
    ```bash
    sudo apt-get update
    sudo apt-get install certbot
    ```

2.  Obtain certificates:
    ```bash
    sudo certbot certonly --standalone -d yourdomain.com
    ```

3.  The certificates will be automatically mounted into the webapp container.

## Authentication

The application uses Auth0 for authentication. Configure the following environment variables:

*   `AUTH0_DOMAIN`: Your Auth0 domain
*   `AUTH0_CLIENT_ID`: Your Auth0 client ID
*   `AUTH0_CLIENT_SECRET`: Your Auth0 client secret
*   `AUTH0_CALLBACK_URL`: Your Auth0 callback URL

## Monitoring

*   Use `docker compose logs` to monitor service logs
*   Set up monitoring tools like Prometheus and Grafana for more detailed monitoring

## Backup

*   Regularly backup your data volumes
*   Use `docker compose down` before taking backups
*   Restore from backups using `docker compose up -d`

## Troubleshooting

*   Check service logs for errors
*   Verify environment variables are set correctly
*   Ensure all required ports are open
*   Check SSL certificate configuration

---