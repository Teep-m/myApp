# Multi-stage build for Jetzig backend
FROM alpine:latest AS builder

# Install build dependencies
RUN apk add --no-cache \
    curl \
    xz \
    git \
    postgresql-dev \
    build-base

# Install Zig (アーキテクチャを自動判別してダウンロード)
RUN arch=$(uname -m) && \
    if [ "$arch" = "x86_64" ]; then \
        ZIG_ARCH="x86_64"; \
    elif [ "$arch" = "aarch64" ]; then \
        ZIG_ARCH="aarch64"; \
    else \
        echo "Unsupported architecture: $arch"; exit 1; \
    fi && \
    curl -L "https://ziglang.org/download/0.13.0/zig-linux-${ZIG_ARCH}-0.13.0.tar.xz" | tar -xJ -C /usr/local && \
    ln -s "/usr/local/zig-linux-${ZIG_ARCH}-0.13.0/zig" /usr/local/bin/zig

# Set working directory
WORKDIR /app

# Copy source code
COPY . .

# Install dependencies and build (Jetzigを使わないので単純なビルド)
RUN zig build -Doptimize=ReleaseSafe

# Runtime stage
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache \
    libpq \
    libstdc++

WORKDIR /app

# Copy built binary from builder
COPY --from=builder /app/zig-out/bin/myapp /app/myapp

# Expose port
EXPOSE 8080

# Run the application
CMD ["/app/myapp"]