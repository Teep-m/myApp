# Multi-stage build for Leptos frontend
FROM rust:latest AS builder

# Install dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install trunk
RUN cargo install trunk

# Add wasm target
RUN rustup target add wasm32-unknown-unknown

WORKDIR /app

# Copy manifest files
COPY Cargo.toml Cargo.lock ./

# Copy source code
COPY . .

# 【修正箇所】
# Cargo.toml でバージョンを固定したので、手動updateコマンドは削除します。
# trunk build が自動的に Cargo.toml に従ったバージョン (0.2.95) を解決します。

# Build the application
RUN trunk build --release

# Runtime stage with nginx
FROM nginx:alpine

# Copy built files to nginx directory
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 3000

CMD ["nginx", "-g", "daemon off;"]