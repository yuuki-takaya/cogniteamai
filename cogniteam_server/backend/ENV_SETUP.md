# 環境変数設定ガイド

このプロジェクトでは、環境変数を`.env`ファイルで管理します。

## .envファイルの作成

`cogniteam_server/backend/`ディレクトリに`.env`ファイルを作成し、以下の内容を設定してください：

```bash
# Firebase Settings
FIREBASE_SERVICE_ACCOUNT_KEY_PATH=handsonadk-firebase-adminsdk-fbsvc-84b61d725e.json

# Vertex AI Settings
VERTEX_AI_PROJECT=your-gcp-project-id
VERTEX_AI_LOCATION=us-central1
VERTEX_AI_CHAT_MODEL_NAME=gemini-1.0-pro
VERTEX_AI_INSIGHT_MODEL_NAME=text-bison@002

# Google AI Agent Settings
GOOGLE_AI_AGENT_MODEL=gemini-2.0-flash
VERTEX_AI_AGENT_ENGINE_ENABLED=true
GOOGLE_API_KEY=your-google-api-key

# Vertex AI Agent Engine Settings (based on Google Cloud documentation)
VERTEX_AI_STAGING_BUCKET=gs://your-gcp-project-id-agent-staging
VERTEX_AI_AGENT_ENGINE_FRAMEWORK=langchain
VERTEX_AI_AGENT_ENGINE_DEPLOYMENT_TIMEOUT=300

# CORS Settings
ALLOWED_ORIGINS=*

# Optional: JWT Settings (if implementing custom JWTs)
# SECRET_KEY=your-secret-key-here
# ALGORITHM=HS256
# ACCESS_TOKEN_EXPIRE_MINUTES=30
```

## 必須設定項目

### Firebase Settings
- `FIREBASE_SERVICE_ACCOUNT_KEY_PATH`: Firebase Admin SDKのサービスアカウントキーファイルのパス

### Vertex AI Settings
- `VERTEX_AI_PROJECT`: Google Cloud PlatformのプロジェクトID
- `VERTEX_AI_LOCATION`: Vertex AIのリージョン（例: us-central1）
- `VERTEX_AI_CHAT_MODEL_NAME`: チャット用のモデル名
- `VERTEX_AI_INSIGHT_MODEL_NAME`: インサイト生成用のモデル名

### Google AI Agent Settings
- `GOOGLE_AI_AGENT_MODEL`: Google AI Agentで使用するモデル名
- `VERTEX_AI_AGENT_ENGINE_ENABLED`: Agent Engineの有効/無効設定
- `GOOGLE_API_KEY`: Google AI APIキー

### Vertex AI Agent Engine Settings
- `VERTEX_AI_STAGING_BUCKET`: Agent Engineのステージングバケット（例: gs://your-project-agent-staging）
- `VERTEX_AI_AGENT_ENGINE_FRAMEWORK`: 使用するフレームワーク（langchain, adk, ag2, llama_index）
- `VERTEX_AI_AGENT_ENGINE_DEPLOYMENT_TIMEOUT`: デプロイメントのタイムアウト時間（秒）

## Google Cloud プロジェクトの設定

[Google Cloud ドキュメント](https://cloud.google.com/vertex-ai/generative-ai/docs/agent-engine/set-up?hl=ja)に基づいて、以下の手順で設定してください：

### 1. Google Cloud プロジェクトの作成・設定
1. Google Cloud アカウントにサインイン
2. プロジェクトセレクターページで、既存のプロジェクトを選択するか、新しいプロジェクトを作成
3. プロジェクトの課金が有効になっていることを確認
4. 必要なAPIを有効化：
   - Vertex AI API
   - Cloud Storage API
   - Cloud Logging API
   - Cloud Monitoring API
   - Cloud Trace API

### 2. 必要なIAMロールの設定
プロジェクトに対して以下のIAMロールを付与：
- Vertex AI ユーザー（`roles/aiplatform.user`）
- ストレージ管理者（`roles/storage.admin`）

### 3. Cloud Storage バケットの作成
Agent Engineのステージング用バケットを作成：
```bash
gcloud storage buckets create gs://your-project-agent-staging \
  --default-storage-class STANDARD \
  --location us-central1
```

### 4. 認証の設定
ローカル開発環境の場合：
```bash
gcloud auth application-default login
```

## 設定手順

1. Google Cloud Platformでプロジェクトを作成
2. 必要なAPIを有効化
3. IAMロールを設定
4. Cloud Storage バケットを作成
5. 認証を設定
6. Google AI APIキーを取得
7. サービスアカウントキーを作成
8. `.env`ファイルを作成し、上記の設定値を入力
9. `GOOGLE_APPLICATION_CREDENTIALS`環境変数を設定（またはサービスアカウントキーファイルを配置）

## 注意事項

- `.env`ファイルはGitにコミットしないでください
- 本番環境では、より安全な方法で環境変数を管理してください
- サービスアカウントキーファイルは適切に保護してください
- Google APIキーは適切に管理してください
- Cloud Storage バケットの権限設定を確認してください
- Agent Engineのデプロイメントには時間がかかる場合があります 