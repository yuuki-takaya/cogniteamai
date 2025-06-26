# CogniTeamAI

CogniTeamAIは、Google AI AgentとVertex AI Agent Engineを統合したチャットアプリケーションです。

## プロジェクト構成

```
test_jules/
├── cogniteam_app/          # Flutterフロントエンド
└── cogniteam_server/       # FastAPIバックエンド
    └── backend/
        ├── .env            # 環境変数設定ファイル（要作成）
        ├── config.py       # 設定管理
        ├── main.py         # アプリケーションエントリーポイント
        ├── services/       # ビジネスロジック
        └── routers/        # APIルーター
```

## セットアップ

### 1. 環境変数の設定

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

# CORS Settings
ALLOWED_ORIGINS=*
```

詳細な設定方法は `cogniteam_server/backend/ENV_SETUP.md` を参照してください。

### 2. バックエンドのセットアップ

```bash
cd cogniteam_server/backend
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

### 3. フロントエンドのセットアップ

```bash
cd cogniteam_app
flutter pub get
```

## 実行

### バックエンド

```bash
cd cogniteam_server/backend
uvicorn main:app --reload
```

### フロントエンド

```bash
cd cogniteam_app
flutter run
```

## 機能

- ユーザーサインアップ時に自動的にGoogle AI Agentを作成
- Vertex AI Agent Engineへの自動登録
- パーソナライズされたチャットエージェント
- リアルタイムチャット機能

## 注意事項

- `.env`ファイルはGitにコミットしないでください
- 本番環境では、より安全な方法で環境変数を管理してください
- サービスアカウントキーファイルは適切に保護してください