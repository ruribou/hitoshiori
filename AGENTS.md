# AGENTS.md

コーディングエージェント向けの作業規約。人間向けの背景説明は README.md を参照。

## このリポジトリについて

「ひとしおり」— 出会った人を最小の手間で記録し、思い出すきっかけをアプリ側から提示する人脈想起アプリ。
Rails 8 API(backend)+ SwiftUI(ios)のモノレポ。

## ドキュメントの読み順

実装タスクに入る前に、この順で読むこと。

1. `docs/product.md` — 課題・設計原則・MVP スコープ。**判断に迷ったらここの設計原則に従う**
2. `docs/tasks/README.md` — タスク一覧と進捗。**次に何をやるかはここが正**
3. `docs/tasks/NN-*.md` — 担当タスクの詳細(スコープ・実装メモ・受け入れ条件)
   - `docs/tasks/` は **git 管理外**(ローカル専用の指示書)。コミットに含めない。
     無い環境では docs/plan.md のロードマップに従う
4. `docs/schema.md` / `docs/api.md` — DB・API 仕様(確定版)。タスクから参照される
5. `docs/plan.md` — 全体ロードマップと決定事項ログ(背景を知りたいとき)

## 作業規約

- 実装は `docs/tasks/` のタスク単位で進める。1 タスク = 1 PR が基本
- 着手時・完了時に `docs/tasks/README.md` の状態欄(未着手 / 進行中 / 完了)を更新する
- タスクファイルの「受け入れ条件」を全て満たしてから完了にする。満たせないものが
  あれば理由をタスクファイルに追記する
- API のエンドポイントを追加・変更したら、同じ PR で `docs/api.md` を更新する
- マイグレーションを追加したら、同じ PR で `docs/schema.md` を更新する
- 仕様を変えたくなったら、docs を先に直してから実装する(実装に合わせて docs を後追いさせない)
- backend のコードを書いたら必ずテストを書く(Minitest)
- コミットメッセージ・コメント・ドキュメントは日本語

## コマンド

### backend(Docker 前提。ホストに Ruby は不要)

```bash
docker compose up -d                                  # 起動(db / backend / jobs)
docker compose exec backend bin/rails test            # テスト
docker compose exec backend bin/rails db:migrate
docker compose exec backend bin/rails g model Person  # ジェネレータ
docker compose exec backend bin/rails c               # コンソール
docker compose logs -f backend                        # ログ
docker compose restart backend jobs                   # Gemfile 変更後の反映
```

疎通確認: `curl -i http://localhost:3000/up` → 200

### ios

```bash
cd ios
xcodegen generate    # project.yml から .xcodeproj を生成(.xcodeproj は git 管理外)
xcodebuild build -scheme Hitoshiori -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test  -scheme Hitoshiori -destination 'platform=iOS Simulator,name=iPhone 17'
```

ターゲット構成・Info.plist・権限まわりの変更は `.xcodeproj` を直接触らず
`ios/project.yml` を編集して `xcodegen generate` を再実行する。

## 技術スタックの固定事項

- ジョブキューは **Solid Queue**(Sidekiq / Redis は使わない)。定期実行は `backend/config/recurring.yml`
- DB は PostgreSQL 17。アプリ本体と queue で DB を分離済み
- iOS は Swift 6 / SwiftUI / iOS 18.0+ / Strict Concurrency complete
- 音声入力は iOS の Speech Framework でオンデバイス文字起こしし、テキストを API に送る。
  サーバ側では音声・自然言語処理をしない(MVP の間)
