# --- ビルダーステージ ---
# バージョンをより具体的に指定し、再現性を高める
FROM golang:1.21.9-alpine3.19 AS builder

# ビルドに必要なパッケージをインストール
RUN apk add --no-cache build-base

# 作業ディレクトリを設定
WORKDIR /app

# Goモジュールの依存関係を先にコピーしてキャッシュを活用
# 'datachain' ディレクトリが存在することを前提としている
COPY datachain/go.mod datachain/go.sum ./
RUN go mod download

# アプリケーションのソースコードをコピー
COPY ./datachain .

# アプリケーションをビルド
# CGO_ENABLED=0: C言語のライブラリに依存しない静的バイナリを生成
# -o /bin/datachaind: 出力先を指定
# -ldflags "-w -s": デバッグ情報を削除し、バイナリサイズを削減
RUN CGO_ENABLED=0 GOOS=linux go build \
	-ldflags="-w -s" \
	-o /bin/datachaind ./cmd/datachaind

# --- 最終ステージ ---
# バージョンをより具体的に指定
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