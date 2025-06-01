# Ultra-lightweight Alpine Linux base for streaming proxy containers
# Optimized for minimal footprint and security
FROM node:20-alpine

# Security: Create non-root user for container execution
RUN addgroup -g 1001 -S proxyuser && \
    adduser -S -D -H -u 1001 -s /sbin/nologin -G proxyuser proxyuser

# Set working directory
WORKDIR /app

# Install only essential dependencies for WebSocket proxy
COPY package.json package-lock.json ./
RUN npm ci --only=production && \
    npm cache clean --force && \
    rm -rf /tmp/* /var/cache/apk/*

# Copy proxy application
COPY proxy-server.js ./
COPY config/ ./config/

# Security: Set proper ownership and permissions
RUN chown -R proxyuser:proxyuser /app && \
    chmod -R 755 /app

# Health check for container monitoring
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:8080/health', (res) => process.exit(res.statusCode === 200 ? 0 : 1))"

# Security: Switch to non-root user
USER proxyuser

# Expose WebSocket proxy port
EXPOSE 8080

# Environment variables for configuration
ENV NODE_ENV=production
ENV PROXY_PORT=8080
ENV LOG_LEVEL=info

# Start the streaming proxy server
CMD ["node", "proxy-server.js"]
