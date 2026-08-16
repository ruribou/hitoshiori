# ひとしおり — よく使うコマンドの入口。
# 一覧は `make` または `make help`。
# macOS 標準の GNU Make 3.81 で動く書き方に留めている(.ONESHELL などは使わない)。

COMPOSE     ?= docker compose
# CI など tty のない環境から叩くときは EXEC_FLAGS=-T を渡す
EXEC_FLAGS  ?=
BACKEND     := $(COMPOSE) exec $(EXEC_FLAGS) backend

IOS_DIR     := ios
SCHEME      := Hitoshiori
PROJECT     := $(SCHEME).xcodeproj
SIMULATOR   ?= iPhone 17
DESTINATION := platform=iOS Simulator,name=$(SIMULATOR)

# 各ターゲットに追加の引数を渡す口(例: make be-test ARGS=spec/models/person_spec.rb)
ARGS        ?=

.DEFAULT_GOAL := help

##@ セットアップ

setup: setup-backend setup-ios ## backend と ios をまとめて構築(初回はこれ一発)
	@echo ""
	@echo "セットアップ完了。 make help でコマンド一覧。"

setup-backend: ## backend を構築して起動し、疎通確認まで行う
	$(COMPOSE) up -d --wait
	@$(MAKE) health

setup-ios: tools ios-gen ios-build ## ios のツール導入・プロジェクト生成・初回ビルド

tools: ## ios 開発に必要な CLI を導入(未導入のものだけ brew install)
	@command -v brew >/dev/null 2>&1 || { echo "Homebrew が必要: https://brew.sh"; exit 1; }
	@for f in xcodegen xcode-build-server swiftlint; do \
		if command -v $$f >/dev/null 2>&1; then \
			echo "導入済み: $$f"; \
		else \
			echo "==> brew install $$f"; brew install $$f; \
		fi; \
	done

doctor: ## 前提コマンドの導入状況を確認
	@for f in docker xcodegen xcode-build-server swiftlint gh; do \
		if command -v $$f >/dev/null 2>&1; then \
			echo "  [ok]   $$f"; \
		else \
			echo "  [未]   $$f"; \
		fi; \
	done

##@ 開発環境(Docker)

up: ## db / backend / jobs を起動
	$(COMPOSE) up -d --wait

down: ## コンテナを停止(DB のデータは残す)
	$(COMPOSE) down

restart: ## backend と jobs を再起動(Gemfile 変更後はこれ)
	$(COMPOSE) restart backend jobs

reset: ## コンテナと DB ボリュームを破棄して作り直す(データは消える)
	$(COMPOSE) down -v
	$(COMPOSE) up -d --wait

ps: ## コンテナの状態
	$(COMPOSE) ps

logs: ## backend のログを追う(例: make logs SERVICE=jobs)
	$(COMPOSE) logs -f $(if $(SERVICE),$(SERVICE),backend)

health: ## /up を叩いて疎通確認
	@curl -fsS -o /dev/null -w 'GET /up -> %{http_code}\n' http://localhost:3000/up

##@ backend(Rails)

be-test: ## RSpec(例: make be-test ARGS=spec/models/person_spec.rb)
	$(BACKEND) bundle exec rspec $(ARGS)

be-lint: ## RuboCop
	$(BACKEND) bundle exec rubocop $(ARGS)

be-lint-fix: ## RuboCop の安全な自動修正
	$(BACKEND) bundle exec rubocop -a $(ARGS)

be-ci: ## backend の全検証(audit / RuboCop / RSpec / seeds)
	$(BACKEND) bin/ci

be-console: ## rails console
	$(BACKEND) bin/rails c

be-sh: ## backend コンテナのシェル
	$(BACKEND) bash

be-migrate: ## db:migrate
	$(BACKEND) bin/rails db:migrate

be-seed: ## seeds を流し直す(db:seed:replant)
	$(BACKEND) bin/rails db:seed:replant

be-routes: ## ルーティング一覧(例: make be-routes ARGS="-g people")
	$(BACKEND) bin/rails routes $(ARGS)

be-rails: ## 任意の rails コマンド(例: make be-rails ARGS="g model Person")
	$(BACKEND) bin/rails $(ARGS)

##@ ios(SwiftUI)

ios-gen: ## project.yml から .xcodeproj と buildServer.json を再生成
	cd $(IOS_DIR) && xcodegen generate
	cd $(IOS_DIR) && xcode-build-server config -project $(PROJECT) -scheme $(SCHEME)

ios-build: ## シミュレータ向けにビルド(例: make ios-build SIMULATOR="iPhone 17 Pro")
	cd $(IOS_DIR) && xcodebuild build -project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' CODE_SIGNING_ALLOWED=NO

ios-test: ## XCTest を実行
	cd $(IOS_DIR) && xcodebuild test -project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(DESTINATION)' CODE_SIGNING_ALLOWED=NO

ios-lint: ## SwiftLint
	cd $(IOS_DIR) && swiftlint lint --config .swiftlint.yml $(ARGS)

ios-open: ## Xcode で開く
	cd $(IOS_DIR) && open $(PROJECT)

##@ タスク(GitHub issue)

track: ## 追跡 issue #22(タスク一覧・依存グラフ)
	gh issue view 22

tasks: ## 未完了の task issue 一覧
	gh issue list --label task --state open

##@ ヘルプ

help: ## このヘルプを表示
	@awk 'BEGIN {FS = ":.*##"; printf "\nひとしおり — make ターゲット一覧\n\n使い方: make <target> [VAR=value]\n"} /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } /^[a-zA-Z0-9_-]+:.*##/ { printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2 } END { printf "\n変数: SIMULATOR(既定 iPhone 17) / SERVICE / ARGS / EXEC_FLAGS\n\n" }' $(MAKEFILE_LIST)

.PHONY: setup setup-backend setup-ios tools doctor \
	up down restart reset ps logs health \
	be-test be-lint be-lint-fix be-ci be-console be-sh be-migrate be-seed be-routes be-rails \
	ios-gen ios-build ios-test ios-lint ios-open \
	track tasks help
