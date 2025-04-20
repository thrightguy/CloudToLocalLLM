FROM dart:stable
WORKDIR /app
RUN apt-get update && apt-get install -y net-tools curl
