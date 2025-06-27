# CloudToLocalLLM AUR Builder Container
# Arch Linux environment for building AUR packages on Ubuntu systems
# Version: 1.0.0

FROM archlinux:latest

# Set environment variables
ENV FLUTTER_VERSION=stable
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="$FLUTTER_HOME/bin:$PATH"
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Create non-root user for building packages (makepkg requires non-root)
RUN useradd -m -G wheel -s /bin/bash builder && \
    echo 'builder ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Update system and install base development tools
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
        base-devel \
        git \
        curl \
        wget \
        unzip \
        which \
        sudo \
        nano \
        vim \
        openssh \
        rsync \
        jq \
        imagemagick \
        gtk3 \
        libayatana-appindicator \
        glibc \
        ca-certificates \
        && pacman -Scc --noconfirm

# Install Flutter SDK
RUN curl -o flutter_linux.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz && \
    tar xf flutter_linux.tar.xz -C /opt && \
    rm flutter_linux.tar.xz && \
    chown -R builder:builder /opt/flutter

# Configure Flutter for the builder user
USER builder
WORKDIR /home/builder

# Initialize Flutter and accept licenses
RUN flutter doctor --android-licenses || true && \
    flutter config --enable-linux-desktop && \
    flutter config --enable-web && \
    flutter doctor

# Create workspace directory
RUN mkdir -p /home/builder/workspace

# Set working directory
WORKDIR /home/builder/workspace

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD flutter doctor --version > /dev/null 2>&1 || exit 1

# Default entrypoint
ENTRYPOINT ["/bin/bash"]
CMD ["--help"]