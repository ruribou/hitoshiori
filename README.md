# ひとしおり

出会った人を最小の手間で記録し、**思い出すのはアプリ側から働きかける**人脈想起アプリ。

学生コミュニティやハッカソンで人に会う機会は多いのに、名前も話した内容も後から出てこない。
この課題を「覚える努力」ではなく「思い出させる仕組み」で解こうとしている。

人に栞を挟んでおいて、必要なときにそのページが開かれる。名前はそこから。

## 設計方針

1. **入力摩擦をゼロに近づける** — 起動して即1画面、名前（あだ名可）＋ワンタップタグ＋音声メモだけ
2. **想起を自動化する** — バッチで「しばらく会っていない人」を抽出し、**1日1人だけ**通知する
3. **継続させる** — 精度より継続。曖昧な名前でも登録でき、後から直せる。記録忘れを煽らない

## 構成

モノレポ。API 仕様のズレに気づきやすく、1セッションで backend / ios 両方に手を入れられるため。

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

| | |
|---|---|
| Backend | Ruby 4.0 / Rails 8.1 (API mode) / PostgreSQL 17 |
| ジョブ | Solid Queue（Redis 不使用。ジョブは Postgres の queue DB に載る） |
| iOS | Swift 6 / SwiftUI / iOS 18.0+ |
| 開発環境 | Docker Compose / XcodeGen |

ジョブキューは Sidekiq ではなく Solid Queue を採用した。Redis というミドルウェアを1つ増やさずに済み、
想起バッチの定期実行も `config/recurring.yml` で完結するため。

## セットアップ

### backend

必要なのは Docker だけ。ホストに Ruby / PostgreSQL は要らない。

```bash
docker compose up -d
```

初回はイメージのビルドが走る。起動すると:

| コンテナ | 中身 |
|---|---|
| `hitoshiori-backend-1` | `bin/rails db:prepare` 後に Puma を :3000 で起動 |
| `hitoshiori-jobs-1` | `bin/jobs`（Solid Queue の supervisor / worker / dispatcher） |
| `hitoshiori-db-1` | PostgreSQL 17 |

疎通確認:

```bash
curl -i http://localhost:3000/up   # => 200
docker compose ps                  # backend が healthy になっていること
```

DB は development / test それぞれでアプリ本体と queue を分けている。
Solid Queue のテーブルがアプリのスキーマに混ざらず、`db:reset` でジョブ用テーブルを巻き込まずに済む。

| | |
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
Xcode の GUI ではなく `ios/project.yml` を編集して `xcodegen generate` し直す。

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

Gemfile を編集したときはコンテナを再起動するだけでよい（起動時に `bundle check` して差分があれば入れ直す）。
gem はイメージではなく名前付きボリュームにあるので、イメージの再ビルドは不要。

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

環境構築まで完了。ここからが MVP の実装。

- [x] モノレポ / Docker Compose / Rails 8 + Solid Queue
- [x] SwiftUI プロジェクト（XcodeGen）
- [ ] Encounter 記録機能（音声 or ワンタップ）
- [ ] 1日1人の想起通知バッチ
- [ ] 通知（APNs）、カレンダー連携（EventKit）、Live Activities
