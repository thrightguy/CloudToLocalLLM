FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    dpkg-dev \
    fakeroot \
    lintian \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libgtk-3-dev \
    libayatana-appindicator3-dev \
    pkg-config \
    cmake \
    ninja-build \
    clang \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git -b stable /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"

# Pre-download Flutter dependencies
RUN flutter doctor
RUN flutter precache --linux

# Create non-root user for building
RUN useradd -m -s /bin/bash builder

# Give builder user ownership of Flutter directory
RUN chown -R builder:builder /opt/flutter

USER builder
WORKDIR /workspace

# Set Flutter path for builder user
ENV PATH="/opt/flutter/bin:${PATH}"

CMD ["/bin/bash"]
