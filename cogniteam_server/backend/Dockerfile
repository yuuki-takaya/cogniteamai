# ベースイメージとしてPython 3.9を使用
FROM python:3.12.1-slim-bookworm
# 作業ディレクトリを /app に設定
WORKDIR /app

# requirements.txtをコンテナにコピー
COPY requirements.txt .

# 依存関係をインストール
RUN pip install -r requirements.txt

# アプリケーションのコードをコンテナにコピー
COPY . .

# 環境変数PORTを定義 (Cloud Runは環境変数PORTを使用してリクエストを送信)
ENV PORT 8080
ENV FIREBASE_SERVICE_ACCOUNT_KEY_PATH=handsonadk-firebase-adminsdk-fbsvc-84b61d725e.json
ENV VERTEX_AI_PROJECT=handsonadk
ENV VERTEX_AI_LOCATION=us-central1
ENV ENV ENV VERTEX_AI_CHAT_MODEL_NAME=gemini-2.0-flash
ENV VERTEX_AI_INSIGHT_MODEL_NAME=text-bison@002

# Google AI Agent Settings
ENV GOOGLE_AI_AGENT_MODEL=gemini-2.0-flash
ENV VERTEX_AI_AGENT_ENGINE_ENABLED=true

# CORS Settings
ENV ALLOWED_ORIGINS=https://handsonadk.web.app,https://handsonadk.firebaseapp.com,http://localhost:3000,http://localhost:8080

# コンテナがリッスンするポートを公開 (必須ではないが、ドキュメントの推奨)
EXPOSE 8080

# アプリケーションを実行するコマンドを定義
# Gunicorn を使用して複数のUvicornワーカーを管理し、FastAPIアプリケーションを実行する
# main:app は main.py ファイル内の app という名前のFastAPIアプリケーションインスタンスを指す
# --bind :$PORT は、Gunicornが指定されたポートでリッスンすることを意味する
# --workers はワーカープロセス数 (CPUコア数などに応じて調整可能。Cloud Runでは1でも十分なことが多い)
# --worker-class uvicorn.workers.UvicornWorker は、Uvicornをワーカーとして使用するようGunicornに指示する
CMD exec gunicorn main:app --bind :$PORT --worker-class uvicorn.workers.UvicornWorker --workers 1 --threads 8 --timeout 0