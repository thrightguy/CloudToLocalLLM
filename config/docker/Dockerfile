# Use the official Flutter image
FROM ghcr.io/cirruslabs/flutter:3.22.0 AS build

# Create a non-root user for building
RUN useradd -ms /bin/bash builder && \
    chown -R builder:builder /sdks/flutter && \
    git config --system --add safe.directory /sdks/flutter

USER builder
WORKDIR /home/builder/app

# Copy files with correct ownership
COPY --chown=builder:builder . .

# Enable null safety and build the app
RUN flutter config --enable-web && \
    flutter pub get && \
    flutter clean && \
    flutter pub upgrade --major-versions && \
    flutter build web --release --no-sound-null-safety

# Use a lightweight server image to serve the web app
FROM nginx:alpine

# Create necessary directories
RUN mkdir -p /usr/share/nginx/html

# Copy Nginx configuration
COPY config/nginx/nginx.conf /etc/nginx/nginx.conf

# Remove the default nginx config that causes user directive errors
RUN rm -f /etc/nginx/conf.d/default.conf

# Copy the built Flutter web app
COPY --from=build /home/builder/app/build/web /usr/share/nginx/html

# Ensure nginx user/group exists (for Alpine)
RUN addgroup -S nginx && adduser -S nginx -G nginx

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off; error_log /dev/stderr info;"]
