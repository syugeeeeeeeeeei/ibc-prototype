# Goのビルド環境と必要なツールを準備するステージ
FROM golang:1.24-alpine AS builder

# ビルドに必要なパッケージをインストール
RUN apk add --no-cache build-base

# 作業ディレクトリを設定
WORKDIR /app

# --- metachainのソースコードをコピー ---
# ローカルのchain/metachainディレクトリをコンテナ内にコピー
COPY ../../chain/metachain /app/metachain

# Goモジュールの依存関係をダウンロード
WORKDIR /app/metachain
RUN go mod download

# --- metachaind バイナリをビルド ---
RUN CGO_ENABLED=0 GOOS=linux go build \
	-ldflags="-w -s" \
	-o /bin/metachaind ./cmd/metachaind

# --- 最終ステージ ---
# 実行に必要な最小限の環境を構築するステージ
FROM alpine:3.19

# セキュリティ向上のため、専用の非rootユーザーを作成
RUN addgroup -S metachain && adduser -S metachain -G metachain

# ビルダーステージからコンパイル済みのバイナリのみをコピー
COPY --from=builder /bin/metachaind /usr/bin/metachaind

# metachaind を実行ユーザーに実行権限を付与
RUN chmod +x /usr/bin/metachaind

# ユーザーを切り替え
USER metachain

# デフォルトのコマンドとしてmetachaindを設定
CMD ["metachaind"]