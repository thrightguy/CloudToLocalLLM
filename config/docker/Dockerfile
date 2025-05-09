# Updated 2025-05-08: Modern Docker image for Flutter/Dart server app
FROM dart:stable AS build

WORKDIR /app

# Copy pubspec files and get dependencies
COPY pubspec.* ./
RUN dart pub get

# Copy the rest of the app
COPY . .

# Build the Dart server/CLI app (example: bin/server.dart)
RUN dart compile exe bin/server.dart -o /output/server

# Final stage - slim image to run the server
FROM scratch
COPY --from=build /output/server /app/server

# Expose port if needed (example: 9001 for admin daemon)
EXPOSE 9001

# Default command to run the server
ENTRYPOINT ["/app/server"]
