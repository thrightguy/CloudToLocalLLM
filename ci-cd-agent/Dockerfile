# CloudToLocalLLM CI/CD Agent Dockerfile
FROM node:18-alpine

# Install system dependencies
RUN apk add --no-cache \
    git \
    bash \
    curl \
    docker-cli \
    docker-compose \
    openssh-client \
    openssl \
    ca-certificates

# Create app directory
WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S cicd && \
    adduser -S cicd -u 1001 -G cicd

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && \
    npm cache clean --force

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p logs public && \
    chown -R cicd:cicd /app

# Switch to non-root user
USER cicd

# Expose port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3001/health || exit 1

# Start the application
CMD ["npm", "start"]
