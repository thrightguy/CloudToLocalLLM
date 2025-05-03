# Cloud Portal Deployment Guide (Render/Docker)

This guide explains how to deploy the CloudToLocalLLM cloud portal (Flutter web) as a standalone service using Docker, suitable for Render.com or similar platforms.

---

## 1. Project Structure for Cloud Portal

- Only include these directories/files in the new GitHub repo:
  - `lib/` (Flutter source code)
  - `web/` (Web entrypoint: index.html, favicon, etc.)
  - `pubspec.yaml` (Flutter dependencies)
  - `Dockerfile` (already configured)
  - `.dockerignore` (already configured)
  - This README

---

## 2. Docker Configuration (Already Implemented)

The Docker setup is already implemented with a multi-stage build for optimal image size:

```dockerfile
# Use the official Dart image to build the web app
FROM dart:stable AS build
WORKDIR /app
COPY . .
RUN dart pub global activate flutter_tools && \
    flutter pub get && \
    flutter build web --release

# Use a lightweight server image to serve the web app
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

This Dockerfile:
1. Uses Dart to build the Flutter web app
2. Creates a minimal Nginx image with only the built assets
3. Results in a small, efficient Docker image

---

## 3. Optimizing the Docker Image

To keep the Docker image as small as possible:

### 3.1 Use the `.dockerignore` file

The `.dockerignore` file prevents unnecessary files from being included in the build context:

```
# Development
.git
.github
.gitignore
.vscode
.idea

# Build artifacts
build/
.dart_tool/

# Tests
test/
*_test.dart

# Documentation
*.md
LICENSE

# Dependencies cached locally
.pub-cache/
.pub/
```

### 3.2 Remove Unnecessary Packages

Before building the Docker image, you can remove any development dependencies that aren't needed in production:

1. Audit `pubspec.yaml` and move development-only packages to `dev_dependencies`
2. Consider using conditional imports to exclude debug tooling in production builds
3. The multi-stage build already eliminates build tools from the final image

---

## 4. How to Build and Run Locally

```sh
# Build the Docker image
# (from the root of the cloud portal repo)
docker build -t cloudtolocalllm-cloud .

# Run the container locally
docker run -p 8080:80 cloudtolocalllm-cloud
```

Then visit [http://localhost:8080](http://localhost:8080) in your browser.

---

## 5. Deploying on Render.com

1. Create a new GitHub repository with only the cloud portal code (see structure above).
2. Push your code to GitHub.
3. On Render.com:
   - Click "+ New Web Service"
   - Connect your repo
   - Set build command: `docker build -t cloudtolocalllm-cloud .`
   - Set start command: `docker run -p 8080:80 cloudtolocalllm-cloud`
   - (Or just let Render detect the Dockerfile)
   - Choose a free or paid plan
   - Deploy!

Your portal will be available at the Render-provided URL.

---

## 6. Non-Technical Notes

- No coding is required to deploy or update the portal—just follow these steps.
- The portal will look and work the same as your local app, but is accessible from anywhere.
- If you need to update the portal, just push changes to GitHub and Render will redeploy automatically.

---

## 7. For Developers

- Ensure only the cloud portal code is in the repo (do not include Windows/native/local files).
- The Dockerfile builds the Flutter web app and serves it with nginx for maximum compatibility.
- For custom domains or HTTPS, see Render.com documentation.
- Regular updates of base images (`dart:stable` and `nginx:alpine`) ensure security patches are applied.

---

If you need a step-by-step video or screenshots, let us know!
