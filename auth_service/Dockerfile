FROM dart:stable

WORKDIR /app

# Copy pubspec files
COPY pubspec.* ./
RUN dart pub get

# Copy source code
COPY . .
RUN dart pub get --offline

# Build the application
RUN dart compile exe bin/auth_service.dart -o bin/server

# Start the service
EXPOSE 8000
CMD ["./bin/server"] 