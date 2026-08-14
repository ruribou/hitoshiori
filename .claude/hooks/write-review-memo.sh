#!/usr/bin/env bash
# コードレビューの指摘を .claude/reviews/ へ必ず残すためのフック。
#
# ReportFindings(コードレビューが指摘を報告するツール)の PostToolUse で発火する。
# レビューの起動方法(/code-review、自然言語での依頼、フォークされたサブエージェント)に
# 依存せず、指摘が報告された瞬間に機械的にファイルへ落とす。
#
# 出力: <リポジトリルート>/.claude/reviews/<ブランチ名>.md
# 書き出したパスは additionalContext でモデルへ戻し、指示書へ仕上げさせる。
set -uo pipefail

payload=$(cat)

cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] || cwd=$PWD
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || root=$cwd

branch=$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)
# feature/task-02-foo -> task-02-foo。スラッシュはファイル名に使えないので潰す
slug=$(printf '%s' "$branch" | sed 's|^feature/||' | tr '/' '-' | tr -cd '[:alnum:]._-')
[ -n "$slug" ] || slug=review

dir="$root/.claude/reviews"
mkdir -p "$dir" || exit 0
out="$dir/$slug.md"

# 一度 temp へ書き、成功したときだけ差し替える。
# 入力が壊れていても既存のメモを消さないため。
tmp=$(mktemp "$dir/.write-review-memo.XXXXXX") || exit 0
trap 'rm -f "$tmp"' EXIT

if ! printf '%s' "$payload" | jq -r \
  --arg branch "$branch" \
  --arg now "$(date '+%Y-%m-%d %H:%M')" \
  --arg base "$(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo unknown)" '
  def loc($f): "`" + $f.file + (if $f.line then ":" + ($f.line | tostring) else "" end) + "`";
  def item($f; $i):
    "### " + ($i | tostring) + ". " + ($f.short_summary // $f.summary) + "\n\n"
    + "- **場所**: " + loc($f) + "\n"
    + "- **種別**: " + ($f.category // "-") + " / 確度: " + ($f.verdict // "-") + "\n"
    + "- **問題**: " + ($f.summary // "-") + "\n"
    + "- **再現・影響**: " + ($f.failure_scenario // "-") + "\n"
    + "- **修正方針**: (未記入)\n"
    + "- **完了条件**: (未記入)\n";
  (.tool_input.findings // []) as $fs
  | "# コードレビュー指摘 (" + $branch + ")\n\n"
  + "- 生成: " + $now + "(ReportFindings フックによる自動出力)\n"
  + "- ブランチ: `" + $branch + "` / HEAD: `" + $base + "`\n"
  + "- 指摘: " + ($fs | length | tostring) + " 件"
  + (if .tool_input.level then " / effort: " + .tool_input.level else "" end) + "\n\n"
  + "> このファイルはフックが機械的に書き出した素の指摘。\n"
  + "> `review-hitoshiori-changes` skill のフォーマットに従い、各指摘へ「修正方針」\n"
  + "> 「完了条件」「仕様の該当箇所」を補い、P1〜P4 の優先度順に整理して仕上げること。\n\n"
  + "---\n\n"
  + (if ($fs | length) == 0 then "## 指摘なし\n\nレビューは実行され、報告された指摘は 0 件だった。\n"
     else "## 指摘一覧(未整理)\n\n"
       + ([$fs | to_entries[] | item(.value; .key + 1)] | join("\n"))
     end)
' > "$tmp" 2>/dev/null; then
  # 書き出しに失敗してもレビュー自体は止めない。既存のメモには触れない
  exit 0
fi

# jq が空を返した(入力が空など)場合も既存のメモを守る
[ -s "$tmp" ] || exit 0
chmod 644 "$tmp" 2>/dev/null
mv "$tmp" "$out" || exit 0

jq -n --arg out "$out" '{
  systemMessage: ("レビュー結果を " + $out + " に書き出しました"),
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: ("ReportFindings の指摘を " + $out + " に自動保存した。"
      + "review-hitoshiori-changes skill の指示書フォーマットに従って、各指摘へ"
      + "「修正方針」「完了条件」「仕様の該当箇所(docs の file:line)」を補い、"
      + "P1(バグ)〜P4(ドキュメント)の優先度順に並べ替えて同じパスへ書き直すこと。"
      + "誤検出は消さずに「対応不要と判断した指摘」へ理由付きで残す。"
      + ".claude/reviews/ は .gitignore 済みなのでコミットしない。")
  }
}'
