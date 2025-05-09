# Updated 2025-05-09: Modern Docker image for Flutter server app
FROM ghcr.io/cirruslabs/flutter:latest AS build

WORKDIR /app

# Setup Flutter user for permission management
RUN groupadd -r flutteruser && useradd --no-log-init -r -g flutteruser -m -s /bin/bash flutteruser
RUN mkdir -p /sdks/flutter/bin/cache && \
    mkdir -p /sdks/flutter/packages/flutter_tools && \
    chown -R flutteruser:flutteruser /sdks/flutter/bin/cache && \
    chown -R flutteruser:flutteruser /sdks/flutter/packages/flutter_tools
RUN git config --global --add safe.directory /sdks/flutter

# Copy pubspec files and get dependencies
COPY --chown=flutteruser:flutteruser pubspec.* ./
USER flutteruser
RUN flutter pub get

# Copy the rest of the app
COPY --chown=flutteruser:flutteruser . .

# Build the server/CLI app (example: bin/server.dart)
RUN dart compile exe bin/server.dart -o /output/server

# Final stage - slim image to run the server
FROM debian:slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /output/server /app/server

# Expose port if needed (example: 9001 for admin daemon)
EXPOSE 9001

# Default command to run the server
ENTRYPOINT ["/app/server"]
