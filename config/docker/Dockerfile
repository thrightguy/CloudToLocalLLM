# Build stage: use official Flutter image
FROM ghcr.io/cirruslabs/flutter:3.22.0 AS build

WORKDIR /home/builder/app
COPY . .
RUN flutter config --enable-web \
    && flutter pub get \
    && flutter clean \
    && flutter pub upgrade --major-versions \
    && flutter build web --release

# Final stage: custom Alpine with nginx
FROM alpine:3.19

# Install nginx and any other tools you need
RUN apk add --no-cache nginx

# Set up directories
RUN mkdir -p /usr/share/nginx/html

# Copy nginx config
COPY config/nginx/nginx.conf /etc/nginx/nginx.conf

# Remove default config if present
RUN rm -f /etc/nginx/conf.d/default.conf || true

# Copy built web app from build stage
COPY --from=build /home/builder/app/build/web /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off; error_log /dev/stderr info;"]
