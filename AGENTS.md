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

よく使うものはルートの `Makefile` にまとめてある。一覧は `make help`。
初回構築は `make setup`(backend の起動・疎通確認 + ios のツール導入・生成・ビルド)。
以下は make ターゲットと、それが実行する素のコマンド。

### タスク(GitHub issue)

```bash
gh issue view 22                                   # 追跡 issue(一覧・依存グラフ) = make track
gh issue list --label task --state open            # 残りのタスク = make tasks
gh issue view <番号>                                # タスクの詳細
gh issue edit <番号> --add-label status:in-progress # 着手をマーク
gh issue comment <番号> --body "..."                # 未達の受け入れ条件などを残す
```

### backend(Docker 前提。ホストに Ruby は不要)

```bash
make up        # docker compose up -d --wait                    起動(db / backend / jobs)
make be-test   # docker compose exec backend bundle exec rspec  テスト
make be-lint   # docker compose exec backend bundle exec rubocop  Ruby・RSpecのLint
make be-ci     # docker compose exec backend bin/ci             backendの全検証
make be-migrate                                               # bin/rails db:migrate
make be-rails ARGS="g model Person"                           # ジェネレータなど任意の rails
make be-console                                               # bin/rails c
make logs      # docker compose logs -f backend                 ログ
make restart   # docker compose restart backend jobs            Gemfile 変更後の反映
```

`make be-test ARGS=spec/models/person_spec.rb` のように `ARGS` で引数を渡せる。
tty のない環境から叩くときは `EXEC_FLAGS=-T` を付ける。

疎通確認: `make health`(= `curl http://localhost:3000/up`)→ 200

### ios

```bash
make setup-ios   # 必要な CLI の導入 → xcodegen generate → buildServer.json 生成 → ビルド
make ios-gen     # .xcodeproj(git 管理外)と buildServer.json を再生成
make ios-build   # xcodebuild build -destination 'platform=iOS Simulator,name=iPhone 17'
make ios-test    # xcodebuild test  同上
make ios-lint    # swiftlint lint
```

シミュレータを変えるときは `make ios-build SIMULATOR="iPhone 17 Pro"`。

ターゲット構成・Info.plist・権限まわりの変更は `.xcodeproj` を直接触らず
`ios/project.yml` を編集して `make ios-gen` を実行する(XcodeGen の再生成と
`buildServer.json` の作り直しをまとめて行う)。その後 `make ios-build` で一度ビルドを通す。
ソースファイルを追加した場合もビルドを通してコンパイル引数を更新する。

## 技術スタックの固定事項

- ジョブキューは **Solid Queue**(Sidekiq / Redis は使わない)。定期実行は `backend/config/recurring.yml`
- DB は PostgreSQL 17。アプリ本体と queue で DB を分離済み
- iOS は Swift 6 / SwiftUI / iOS 18.0+ / Strict Concurrency complete
- 音声入力は iOS の Speech Framework でオンデバイス文字起こしし、テキストを API に送る。
  サーバ側では音声・自然言語処理をしない(MVP の間)
