# Cloud Portal Deployment Guide (Render/Docker)

This guide explains how to deploy the CloudToLocalLLM cloud portal (Flutter web) as a standalone service using Docker, suitable for Render.com or similar platforms.

---

## 1. Project Structure for Cloud Portal

- Only include these directories/files in the new GitHub repo:
  - `lib/` (Flutter source code)
  - `web/` (Web entrypoint: index.html, favicon, etc.)
  - `pubspec.yaml` (Flutter dependencies)
  - `Dockerfile` (see below)
  - This README

---

## 2. Dockerfile for Flutter Web

```
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

---

## 3. How to Build and Run Locally

```sh
# Build the Docker image
# (from the root of the cloud portal repo)
docker build -t cloudtolocalllm-cloud .

# Run the container locally
docker run -p 8080:80 cloudtolocalllm-cloud
```

Then visit [http://localhost:8080](http://localhost:8080) in your browser.

---

## 4. Deploying on Render.com

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

## 5. Non-Technical Notes

- No coding is required to deploy or update the portal—just follow these steps.
- The portal will look and work the same as your local app, but is accessible from anywhere.
- If you need to update the portal, just push changes to GitHub and Render will redeploy automatically.

---

## 6. For Developers

- Ensure only the cloud portal code is in the repo (do not include Windows/native/local files).
- The Dockerfile builds the Flutter web app and serves it with nginx for maximum compatibility.
- For custom domains or HTTPS, see Render.com documentation.

---

If you need a step-by-step video or screenshots, let us know!
