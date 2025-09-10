# ベースイメージを指定
FROM ubuntu:22.04

# 必要なパッケージをインストール (ここに golang を追加)
RUN apt-get update && apt-get install -y curl

ENV GO_VERSION=1.24.0
RUN curl -L "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:${PATH}"

# Ignite CLIをインストール
RUN curl -sSfL https://get.ignite.com/cli! | bash

# 作業ディレクトリを設定
WORKDIR /app

# --- metachainの雛形をDockerfile内で動的に生成する ---
RUN ignite scaffold chain metachain --skip-git
RUN ignite scaffold module metadata --ibc --dep bank --yes
# 要求されたデータ構造 {url:string, address_hash:string[]} を持つIBCパケットを作成
RUN ignite scaffold packet metaData url:string addressHashes:array.string --module metadata --yes

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
