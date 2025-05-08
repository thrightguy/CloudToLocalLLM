# Updated 2025-05-08: Modern Docker image for Flutter app
FROM cirrusci/flutter:stable AS build

# Set Flutter environment variables to suppress root user warnings
ENV FLUTTER_ROOT=/flutter 
ENV PUB_CACHE=/flutter/.pub-cache
ENV FLUTTER_SUPPRESS_ANALYTICS=true
ENV NO_COLOR=true
ENV FLUTTER_NO_ROOT_WARNING=true

WORKDIR /app

# Copy scripts first
COPY scripts/setup/docker_android_fix.sh /app/docker_android_fix.sh
RUN chmod +x /app/docker_android_fix.sh

# Copy pubspec files
COPY pubspec.* ./
RUN flutter pub get

# Copy the rest of the app
COPY . .

# Fix Android embedding issues
RUN /app/docker_android_fix.sh

# Build the app
RUN flutter clean && flutter build apk --release

# Copy the built app to a known location
RUN mkdir -p /output && cp build/app/outputs/flutter-apk/app-release.apk /output/app-release.apk

# Final stage - slim image to serve the app
FROM alpine:latest

WORKDIR /app
COPY --from=build /output/app-release.apk /app/app-release.apk

# Expose port if needed for download server
EXPOSE 8080

# Use a simple HTTP server to serve the APK if needed
CMD ["echo", "APK build complete. Use Docker cp to extract the APK."]
