# Updated 2025-05-08: Use stable official Docker images
# Build stage: use popular, widely-supported cirrusci/flutter image
FROM cirrusci/flutter:stable AS build

WORKDIR /app
# Copy only pubspec files first for better caching
COPY pubspec.* ./
RUN flutter pub get
# Now copy the rest of the source
COPY . .
RUN flutter config --enable-web \
    && flutter build web --release

# Final stage: use official nginx alpine image
FROM nginx:alpine

# Copy built web app from build stage to nginx html directory
COPY --from=build /app/build/web /usr/share/nginx/html

# Copy nginx config
COPY config/nginx/nginx.conf /etc/nginx/nginx.conf

# Expose port 80
EXPOSE 80

# Default command uses nginx's standard configuration
CMD ["nginx", "-g", "daemon off;"]
