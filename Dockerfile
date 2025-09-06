# --- ビルダーステージ ---
# Goのビルド環境として公式イメージを使用
FROM golang:1.21-alpine AS builder

# 作業ディレクトリを設定
WORKDIR /app

# Goモジュールの依存関係を先にコピーしてキャッシュを活用
COPY datachain/go.mod datachain/go.sum ./
RUN go mod download

# アプリケーションのソースコードをコピー
COPY ./datachain .

# アプリケーションをビルド
# CGO_ENABLED=0: C言語のライブラリに依存しない静的バイナリを生成
# -o /bin/datachaind: 出力先を指定
RUN CGO_ENABLED=0 GOOS=linux go build -o /bin/datachaind ./cmd/datachaind

# --- 最終ステージ ---
# 軽量なAlpine Linuxをベースイメージとして使用
FROM alpine:latest

# ビルダーステージからコンパイル済みのバイナリのみをコピー
COPY --from=builder /bin/datachaind /usr/bin/datachaind

# datachaind を実行ユーザーに実行権限を付与
RUN chmod +x /usr/bin/datachaind

# デフォルトのコマンドとしてdatachaindを設定
CMD ["datachaind"]