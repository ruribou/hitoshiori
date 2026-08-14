# ひとしおり

出会った人を最小の手間で記録し、思い出すきっかけをアプリ側から提示する人脈想起アプリ。

学生コミュニティやハッカソンでは人に会う機会が多い一方、名前も話した内容も後から出てこない。
「覚える努力」ではなく「思い出させる仕組み」で解決する。

人に栞を挟んでおき、必要なときにそのページが開かれる。名前の由来。

## 設計方針

- 入力摩擦の最小化 — 1 画面で完結。名前（あだ名可）+ ワンタップのタグ + 音声メモ
- 想起の自動化 — しばらく会っていない人物をバッチ抽出し、1 日 1 人に絞って通知
- 継続性の優先 — 曖昧な名前でも登録可、後から修正可能。記録忘れは通知しない

## 構成

モノレポ構成。API 仕様のズレを検知しやすく、1 セッションで backend / ios 双方に手を入れられる。

```
hitoshiori/
├── AGENTS.md         # コーディングエージェント向けの作業規約(正本)
├── CLAUDE.md         # Claude Code 用。@AGENTS.md を読み込むだけ
├── compose.yml       # ローカル開発環境(db / backend / jobs)
├── backend/          # Rails 8 API + Solid Queue
├── ios/              # SwiftUI (XcodeGen で .xcodeproj を生成)
└── docs/
    ├── product.md    # 課題・設計原則・MVP スコープ(企画の正本)
    ├── plan.md       # 全体ロードマップと決定事項ログ
    ├── api.md        # エンドポイント仕様
    └── schema.md     # DB 設計
```

### 技術スタック

| 領域 | 技術 |
|---|---|
| Backend | Ruby 4.0 / Rails 8.1 (API mode) / PostgreSQL 17 |
| ジョブ | Solid Queue（Redis 不使用。ジョブは Postgres の queue DB に格納） |
| iOS | Swift 6 / SwiftUI / iOS 18.0+ |
| 開発環境 | Docker Compose / XcodeGen |

ジョブキューは Sidekiq ではなく Solid Queue を採用。Redis の追加が不要で、
想起バッチの定期実行も `config/recurring.yml` で完結するため。

## セットアップ

### backend

前提: Docker のみ（ホストへの Ruby / PostgreSQL のインストールは不要）

```bash
docker compose up -d
```

初回はイメージのビルドが走る。起動するコンテナ:

| コンテナ | 内容 |
|---|---|
| `hitoshiori-backend-1` | `bin/rails db:prepare` 後に Puma を :3000 で起動 |
| `hitoshiori-jobs-1` | `bin/jobs`（Solid Queue の supervisor / worker / dispatcher） |
| `hitoshiori-db-1` | PostgreSQL 17 |

疎通確認:

```bash
curl -i http://localhost:3000/up   # => 200
docker compose ps                  # backend が healthy
```

DB は development / test それぞれでアプリ本体と queue を分離。
Solid Queue のテーブルがアプリのスキーマに混ざらず、`db:reset` の巻き込みも防げる。

| DB | 用途 |
|---|---|
| `hitoshiori_development` | アプリ本体 |
| `hitoshiori_development_queue` | Solid Queue |
| `hitoshiori_test` / `hitoshiori_test_queue` | テスト用 |

### ios

```bash
cd ios
xcodegen generate          # project.yml から Hitoshiori.xcodeproj を生成
open Hitoshiori.xcodeproj
```

`.xcodeproj` は生成物のため git 管理外。ターゲット構成やビルド設定の変更は
`ios/project.yml` を編集して `xcodegen generate` を再実行する。

シミュレータからは `http://localhost:3000` でホストの backend に到達。
起動直後の画面が backend のヘルスチェック結果を表示するため、そのまま疎通確認に使える。

## よく使うコマンド

### backend

```bash
docker compose up -d                                  # 起動
docker compose down                                   # 停止
docker compose down -v                                # DB ごと破棄
docker compose logs -f backend                        # ログ
docker compose exec backend bash                      # シェル
docker compose exec backend bin/rails c               # コンソール
docker compose exec backend bin/rails test            # テスト
docker compose exec backend bin/rails db:migrate
docker compose exec backend bin/rails g model Person  # ジェネレータ
```

Gemfile 変更時はコンテナの再起動のみ（起動時に `bundle check` し、差分があれば再インストール）。
gem はイメージではなく名前付きボリュームに配置しているため、イメージの再ビルドは不要。

```bash
docker compose restart backend jobs
```

### ios

```bash
cd ios
xcodegen generate
xcodebuild build -scheme Hitoshiori -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test  -scheme Hitoshiori -destination 'platform=iOS Simulator,name=iPhone 17'
```
