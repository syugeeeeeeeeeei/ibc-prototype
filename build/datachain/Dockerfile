# --- ビルダーステージ ---
# Goのビルド環境と必要なツールを準備するステージ
FROM golang:1.24-alpine AS builder

# ビルドに必要なパッケージをインストール
# ▼▼▼ bash をここに追加 ▼▼▼
RUN apk add --no-cache build-base curl bash

# Ignite CLIをインストール
RUN curl -sSfL https://get.ignite.com/cli! | bash

# 作業ディレクトリを設定
WORKDIR /app

# --- datachainの雛形をDockerfile内で動的に生成する ---
RUN ignite scaffold chain datachain --skip-git
RUN ignite scaffold module datastore --ibc --dep bank --yes
RUN ignite scaffold packet chunk index:string data:bytes --module datastore --yes
RUN ignite scaffold map stored-chunk data:bytes --module datastore --signer creator --yes

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