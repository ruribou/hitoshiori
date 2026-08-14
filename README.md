# ひとしおり

出会った人を最小の手間で記録して、思い出すほうはアプリ側から声をかけてくる人脈想起アプリ。

学生コミュニティやハッカソンで人に会う機会は多いのに、名前も話した内容も後から出てこない。
これを「覚える努力」ではなく「思い出させる仕組み」で解きたい。

人に栞を挟んでおいて、必要なときにそのページが開かれる。名前はそこから。

## 設計方針

入力の摩擦をできるだけゼロに近づける。起動して即1画面、名前（あだ名でもいい）とワンタップのタグ、あとは音声メモだけ。

想起は自動でやる。バッチでしばらく会っていない人を拾って、1日1人だけ通知する。

精度より継続を優先する。曖昧な名前でも登録できて後から直せるようにして、記録忘れを煽る通知はしない。

## 構成

モノレポにしている。API 仕様のズレに気づきやすいのと、1セッションで backend と ios の両方に手を入れられるので。

```
hitoshiori/
├── compose.yml       # ローカル開発環境(db / backend / jobs)
├── backend/          # Rails 8 API + Solid Queue
├── ios/              # SwiftUI (XcodeGen で .xcodeproj を生成)
└── docs/
    ├── api.md        # エンドポイント仕様
    └── schema.md     # DB 設計
```

### 技術スタック

- Backend: Ruby 4.0 / Rails 8.1 (API mode) / PostgreSQL 17
- ジョブ: Solid Queue（Redis は使わない。ジョブは Postgres の queue DB に載る）
- iOS: Swift 6 / SwiftUI / iOS 18.0+
- 開発環境: Docker Compose / XcodeGen

ジョブキューは Sidekiq ではなく Solid Queue にした。Redis というミドルウェアを1つ増やさずに済むし、
想起バッチの定期実行も `config/recurring.yml` だけで書けるので。

## セットアップ

### backend

必要なのは Docker だけ。ホストに Ruby や PostgreSQL は要らない。

```bash
docker compose up -d
```

初回はイメージのビルドが走る。起動すると以下が立ち上がる。

| コンテナ | 中身 |
|---|---|
| `hitoshiori-backend-1` | `bin/rails db:prepare` のあと Puma を :3000 で起動 |
| `hitoshiori-jobs-1` | `bin/jobs`（Solid Queue の supervisor / worker / dispatcher） |
| `hitoshiori-db-1` | PostgreSQL 17 |

疎通確認:

```bash
curl -i http://localhost:3000/up   # => 200
docker compose ps                  # backend が healthy になっていること
```

DB は development / test それぞれでアプリ本体と queue を分けてある。
Solid Queue のテーブルがアプリのスキーマに混ざらないし、`db:reset` でジョブ用テーブルを巻き込まずに済む。

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

`.xcodeproj` は生成物なので git 管理していない。ターゲット構成やビルド設定を変えるときは
Xcode の GUI ではなく `ios/project.yml` を編集して `xcodegen generate` をやり直す。

シミュレータからは `http://localhost:3000` でホストの backend に届く。
起動直後の画面が backend のヘルスチェック結果を出すので、そのまま疎通確認に使える。

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

Gemfile を編集したときはコンテナを再起動するだけでいい（起動時に `bundle check` して差分があれば入れ直す）。
gem はイメージではなく名前付きボリュームにあるので、イメージの再ビルドは要らない。

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

## 実装状況

環境構築まで。ここからが MVP の実装。

- [x] モノレポ / Docker Compose / Rails 8 + Solid Queue
- [x] SwiftUI プロジェクト（XcodeGen）
- [ ] Encounter 記録機能（音声 or ワンタップ）
- [ ] 1日1人の想起通知バッチ
- [ ] 通知（APNs）、カレンダー連携（EventKit）、Live Activities
