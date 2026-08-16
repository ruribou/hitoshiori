# AGENTS.md

コーディングエージェント向けの作業規約。人間向けの背景説明は README.md を参照。

## このリポジトリについて

「ひとしおり」— 出会った人を最小の手間で記録し、思い出すきっかけをアプリ側から提示する人脈想起アプリ。
Rails 8 API(backend)+ SwiftUI(ios)のモノレポ。

## ドキュメントの読み順

実装タスクに入る前に、この順で読むこと。

1. `docs/product.md` — 課題・設計原則・MVP スコープ。**判断に迷ったらここの設計原則に従う**
2. 追跡 issue [#22](https://github.com/ruribou/hitoshiori/issues/22) — タスク一覧・依存グラフ・進め方。
   **次に何をやるかはここが正**
3. `task` ラベルの issue — 担当タスクの詳細(ゴール・スコープ・実装メモ・受け入れ条件)
   - 本文は `gh issue view <番号>` で読む。進捗は issue の open / close が正
4. `docs/schema.md` / `docs/api.md` — DB・API 仕様(確定版)。タスクから参照される
5. `docs/plan.md` — 全体ロードマップと決定事項ログ(背景を知りたいとき)

## 作業規約

- 実装は `task` ラベルの issue 単位で進める。1 issue = 1 PR が基本
- 番号付き実装タスクは、PR不要と明示されない限り、受け入れ条件の確認後に
  commit・push・PR作成まで自動で行う
- **PR 本文に `Closes #<issue番号>` を必ず書く。** マージで issue が自動クローズされ、
  追跡 issue のチェックリストも自動で埋まる
- 未マージの依存タスクを土台にする場合は、その依存PRのブランチをbaseにした
  Stacked PRとして作成する。自動マージはしない
- 着手時に対象 issue へ `status:in-progress` ラベルを付ける。完了はマージ時の
  自動クローズに任せ、手動でクローズしない
- issue の「受け入れ条件」を全て満たしてから完了にする。満たせないものが
  あれば理由を issue にコメントで残す
- API のエンドポイントを追加・変更したら、同じ PR で `docs/api.md` を更新する
- マイグレーションを追加したら、同じ PR で `docs/schema.md` を更新する
- 仕様を変えたくなったら、docs と対象 issue の本文を先に直してから実装する
  (実装に合わせて docs を後追いさせない)
- backend のコードを書いたら必ずテストを書く(RSpec)
- RSpec のテスト用インスタンスは `let` / `let!` で定義し、example 内で直接生成しない
- コミットメッセージ・コメント・ドキュメントは日本語

## コマンド

### タスク(GitHub issue)

```bash
gh issue view 22                                   # 追跡 issue(一覧・依存グラフ)
gh issue list --label task --state open            # 残りのタスク
gh issue view <番号>                                # タスクの詳細
gh issue edit <番号> --add-label status:in-progress # 着手をマーク
gh issue comment <番号> --body "..."                # 未達の受け入れ条件などを残す
```

### backend(Docker 前提。ホストに Ruby は不要)

```bash
docker compose up -d                                  # 起動(db / backend / jobs)
docker compose exec backend bundle exec rspec          # テスト
docker compose exec backend bundle exec rubocop        # Ruby・RSpecのLint
docker compose exec backend bin/ci                     # backendの全検証
docker compose exec backend bin/rails db:migrate
docker compose exec backend bin/rails g model Person  # ジェネレータ
docker compose exec backend bin/rails c               # コンソール
docker compose logs -f backend                        # ログ
docker compose restart backend jobs                   # Gemfile 変更後の反映
```

疎通確認: `curl -i http://localhost:3000/up` → 200

### ios

```bash
brew install xcode-build-server

cd ios
xcodegen generate    # project.yml から .xcodeproj を生成(.xcodeproj は git 管理外)
xcode-build-server config -project Hitoshiori.xcodeproj -scheme Hitoshiori
xcodebuild build -scheme Hitoshiori -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test  -scheme Hitoshiori -destination 'platform=iOS Simulator,name=iPhone 17'
```

ターゲット構成・Info.plist・権限まわりの変更は `.xcodeproj` を直接触らず
`ios/project.yml` を編集して `xcodegen generate` を再実行する。再生成後は
`xcode-build-server config` で `buildServer.json` を作り直し、一度ビルドを通す。
ソースファイルを追加した場合もビルドを通してコンパイル引数を更新する。

## 技術スタックの固定事項

- ジョブキューは **Solid Queue**(Sidekiq / Redis は使わない)。定期実行は `backend/config/recurring.yml`
- DB は PostgreSQL 17。アプリ本体と queue で DB を分離済み
- iOS は Swift 6 / SwiftUI / iOS 18.0+ / Strict Concurrency complete
- 音声入力は iOS の Speech Framework でオンデバイス文字起こしし、テキストを API に送る。
  サーバ側では音声・自然言語処理をしない(MVP の間)
