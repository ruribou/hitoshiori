# syntax=docker/dockerfile:1
ARG RUBY_VERSION=4.0
FROM ruby:${RUBY_VERSION}-slim

# BUNDLE_PATH はあえて指定しない。ruby イメージ既定の GEM_HOME(/usr/local/bundle) に
# 入れておけば binstub が /usr/local/bundle/bin = PATH 上に置かれ、
# `rails` / `bin/jobs` を bundle exec なしで叩ける。
ENV LANG=C.UTF-8 \
    TZ=Asia/Tokyo \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3

# pg / rails / デバッグに必要な最小限のパッケージ
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      curl \
      git \
      libpq-dev \
      libyaml-dev \
      pkg-config \
      postgresql-client \
      tzdata && \
    rm -rf /var/lib/apt/lists/*

# ディレクトリ名がそのまま Rails のアプリ名(module Hitoshiori)になる
WORKDIR /hitoshiori

# Gemfile だけ先に入れて gem をイメージにベイクしておく。
# 実行時は compose の名前付きボリューム(bundle)に引き継がれるので、
# gem を足したときにイメージを再ビルドしなくても bundle install だけで済む。
COPY Gemfile* ./
RUN bundle install

COPY --chmod=755 <<'ENTRYPOINT' /usr/local/bin/dev-entrypoint
#!/bin/bash
set -e

# Gemfile を編集したまま起動しても落ちないように、差分があれば入れ直す
if [ -f Gemfile ]; then
  bundle check >/dev/null 2>&1 || bundle install
fi

# 異常終了後に残った pid で server が起動できなくなるのを防ぐ
rm -f tmp/pids/server.pid

exec "$@"
ENTRYPOINT

ENTRYPOINT ["dev-entrypoint"]

EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
