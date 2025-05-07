FROM alpine:latest

# Install necessary tools
RUN apk add --no-cache \
    bash \
    curl \
    wget \
    jq \
    htop \
    procps \
    tcpdump \
    netcat-openbsd \
    nginx \
    supervisor \
    tzdata \
    ca-certificates \
    python3 \
    py3-pip

# Install Python libraries
RUN pip3 install --no-cache-dir flask requests psutil

# Create directories
RUN mkdir -p /app /app/logs /app/scripts /var/log/supervisor

# Set up Nginx
RUN mkdir -p /run/nginx
COPY nginx.conf /etc/nginx/http.d/default.conf

# Copy monitoring scripts
COPY scripts/ /app/scripts/
COPY monitor.py /app/
COPY supervisord.conf /etc/supervisord.conf

# Make scripts executable
RUN chmod +x /app/scripts/*.sh /app/monitor.py

# Expose ports for web UI
EXPOSE 8888

# Start supervisord
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"] 