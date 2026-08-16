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
├── Makefile          # よく使うコマンドの入口(make help で一覧)
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

前提は Docker と、ios を触るなら Xcode / Homebrew のみ。あとは一発で揃う。

```bash
make setup     # backend の起動・疎通確認 + ios のツール導入・プロジェクト生成・初回ビルド
```

片側だけなら `make setup-backend` / `make setup-ios`。以下は中身の説明。

### backend

前提: Docker のみ（ホストへの Ruby / PostgreSQL のインストールは不要）

```bash
make up        # = docker compose up -d --wait
```

初回はイメージのビルドが走る。起動するコンテナ:

| コンテナ | 内容 |
|---|---|
| `hitoshiori-backend-1` | `bin/rails db:prepare` 後に Puma を :3000 で起動 |
| `hitoshiori-jobs-1` | `bin/jobs`（Solid Queue の supervisor / worker / dispatcher） |
| `hitoshiori-db-1` | PostgreSQL 17 |

疎通確認:

```bash
make health    # GET /up -> 200
make ps        # backend が healthy
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
make setup-ios   # xcodegen / xcode-build-server / swiftlint の導入 → 生成 → ビルド
make ios-open    # Xcode で開く
```

`.xcodeproj` は生成物のため git 管理外。ターゲット構成やビルド設定の変更は
`ios/project.yml` を編集して `make ios-gen`（XcodeGen による再生成と、SourceKit-LSP 用
`buildServer.json` の作り直し）を実行し、`make ios-build` で一度ビルドを通す。
ソースファイルを追加した場合も同様にビルドする。

`buildServer.json` はローカルの DerivedData の絶対パスを含むため git 管理しない。Zed など
SourceKit-LSP を使うエディタでは、このファイルにより iOS SDK とアプリ全体のコンパイル引数を取得できる。

シミュレータからは `http://localhost:3000` でホストの backend に到達。
起動直後の画面が backend のヘルスチェック結果を表示するため、そのまま疎通確認に使える。

## よく使うコマンド

ルートの `Makefile` にまとめてある。一覧は `make help`。

### 開発環境

| コマンド | 内容 |
|---|---|
| `make up` / `make down` | 起動 / 停止（DB のデータは残る） |
| `make restart` | backend と jobs を再起動（Gemfile 変更時はこれ） |
| `make reset` | コンテナと DB ボリュームを破棄して作り直す |
| `make logs` | backend のログ（`make logs SERVICE=jobs` で切り替え） |
| `make ps` / `make health` | 状態確認 / `/up` の疎通確認 |
| `make doctor` | 前提コマンドの導入状況を確認 |

Gemfile 変更時はコンテナの再起動のみ（起動時に `bundle check` し、差分があれば再インストール）。
gem はイメージではなく名前付きボリュームに配置しているため、イメージの再ビルドは不要。

### backend

| コマンド | 内容 |
|---|---|
| `make be-test` | RSpec（`ARGS=spec/models/person_spec.rb` で絞り込み） |
| `make be-lint` / `make be-lint-fix` | RuboCop / 安全な自動修正 |
| `make be-ci` | backend の全検証（audit / RuboCop / RSpec / seeds） |
| `make be-console` / `make be-sh` | rails console / コンテナのシェル |
| `make be-migrate` / `make be-seed` | db:migrate / db:seed:replant |
| `make be-routes` | ルーティング一覧（`ARGS="-g people"`） |
| `make be-rails ARGS="g model Person"` | 任意の rails コマンド |

### ios

| コマンド | 内容 |
|---|---|
| `make ios-gen` | `.xcodeproj` と `buildServer.json` を再生成 |
| `make ios-build` / `make ios-test` | ビルド / XCTest（`SIMULATOR="iPhone 17 Pro"` で変更） |
| `make ios-lint` | SwiftLint |
| `make ios-open` | Xcode で開く |
