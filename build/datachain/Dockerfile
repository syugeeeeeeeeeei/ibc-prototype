# --- ビルダーステージ ---
# Goのビルド環境と必要なツールを準備するステージ
FROM golang:1.24-alpine AS builder

# ビルドに必要なパッケージをインストール
RUN apk add --no-cache build-base

# 作業ディレクトリを設定
WORKDIR /app

# --- datachainのソースコードをコピー ---
# ローカルのchain/datachainディレクトリをコンテナ内にコピー
COPY ../../chain/datachain /app/datachain

# Goモジュールの依存関係をダウンロード
WORKDIR /app/datachain
RUN go mod download

# --- datachaind バイナリをビルド ---
RUN CGO_ENABLED=0 GOOS=linux go build \
	-ldflags="-w -s" \
	-o /bin/datachaind ./cmd/datachaind

# --- 最終ステージ ---
# 実行に必要な最小限の環境を構築するステージ
FROM alpine:3.19

# セキュリティ向上のため、専用の非rootユーザーを作成
RUN addgroup -S datachain && adduser -S datachain -G datachain

# ビルダーステージからコンパイル済みのバイナリのみをコピー
COPY --from=builder /bin/datachaind /usr/bin/datachaind

# datachaind を実行ユーザーに実行権限を付与
RUN chmod +x /usr/bin/datachaind

# ユーザーを切り替え
USER datachain

# デフォルトのコマンドとしてdatachaindを設定
CMD ["datachaind"]