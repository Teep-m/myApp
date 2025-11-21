# ベースイメージを Debian (glibc系) に変更
FROM debian:bookworm-slim AS builder

# ビルド依存パッケージのインストール (aptを使用)
RUN apt-get update && apt-get install -y \
    curl \
    xz-utils \
    git \
    libpq-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Zigのインストール (アーキテクチャ自動判別)
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

WORKDIR /app

COPY . .

# ビルド実行
RUN zig build -Doptimize=ReleaseSafe

# ランタイムステージも Debian に合わせる
FROM debian:bookworm-slim

# 実行時依存パッケージ (PostgreSQLクライアントライブラリ)
RUN apt-get update && apt-get install -y \
    libpq5 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ビルド成果物のコピー
COPY --from=builder /app/zig-out/bin/myapp /app/myapp

EXPOSE 8080

CMD ["/app/myapp"]