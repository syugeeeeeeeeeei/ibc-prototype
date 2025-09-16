# --- ビルダーステージ ---
# Goのビルド環境と必要なツールを準備するステージ
FROM ubuntu:22.04 AS builder

# ビルドに必要なパッケージをインストール
# GoとIgnite CLIのインストールに必要なツールをまとめる
RUN apt-get update && apt-get install -y curl git make && rm -rf /var/lib/apt/lists/*

# Goをインストール
ENV GO_VERSION=1.24.6
RUN curl -L "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:${PATH}"

# Ignite CLIをインストール
RUN curl -sSfL https://get.ignite.com/cli! | bash
ENV PATH="/root/go/bin:${PATH}"

COPY ./chain/datachain /app/datachain

WORKDIR /app/datachain

# --- datachaind バイナリをビルド ---
# ignite chain build コマンドは $GOPATH/bin にバイナリを生成する
# この場合、コンテナ内のGoのデフォルトのGOPATHは /root/go であるため、
# バイナリは /root/go/bin/datachaind に生成される
RUN ignite chain build

# --- 最終ステージ ---
# 実行に必要な最小限の環境を構築するステージ
FROM alpine:3.19

# セキュリティ向上のため、専用の非rootユーザーを作成
RUN addgroup -S datachain && adduser -S datachain -G datachain

# ビルダーステージからコンパイル済みのバイナリをコピー
# パスを /root/go/bin/datachaind に修正
COPY --from=builder /root/go/bin/datachaind /usr/bin/datachaind

# datachaind を実行ユーザーに実行権限を付与
RUN chmod +x /usr/bin/datachaind

# ユーザーを切り替え
USER datachain

# デフォルトのコマンドとしてdatachaindを設定
CMD ["datachaind"]