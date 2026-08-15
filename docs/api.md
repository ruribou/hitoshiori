# API 仕様

> **状態: MVP 分は確定。** エンドポイントの追加・変更は同じ PR でこのファイルを更新し、
> iOS 側との認識ズレを防ぐ。

## 共通事項

| 項目 | 内容 |
|---|---|
| ベース URL(ローカル) | `http://localhost:3000` |
| プレフィックス | `/api/v1` |
| フォーマット | JSON(リクエスト・レスポンスとも) |
| 認証 | なし(MVP は単一ユーザー前提) |
| 日時 | ISO 8601。リクエストはタイムゾーン付き、レスポンスは UTC |
| 不正なリクエスト | `400 Bad Request` + `{ "errors": { "encounter": ["を入力してください"] } }` |
| バリデーションエラー | `422 Unprocessable Content` + `{ "errors": { "field": ["メッセージ"] } }` |
| 存在しない ID | `404 Not Found` + `{ "errors": { "base": ["not found"] } }` |

## GET /up

Rails 組み込みヘルスチェック。アプリが起動していれば 200。iOS の疎通確認画面が使用中。

---

## POST /api/v1/encounters

出会いを記録する。記録画面から呼ばれる MVP の中心 API。

- `person_id` を渡せば既存人物への追記、`person_name` だけなら**新規人物を作成**する
- どちらも無い/両方空なら 422。両方ある場合は `person_id` を優先
- `met_at` が省略・null・空文字ならサーバの現在時刻。不正な日時形式は 422
- `tag_names` は文字列の配列。省略時は空配列として扱い、配列以外または文字列以外の要素は 422
- `tag_names` のタグは無ければ作成される
- 成功時、対象人物の `last_encountered_at` が更新される

リクエスト

```json
{
  "encounter": {
    "person_name": "たなか",
    "met_at": "2026-08-14T19:00:00+09:00",
    "topic": "ハッカソンで同じチーム",
    "memo": "音声文字起こしのテキスト。Rails が好きらしい。",
    "tag_names": ["ハッカソン", "STECH"]
  }
}
```

既存人物への追記の場合は `person_name` の代わりに `"person_id": 1`。

レスポンス `201 Created`

```json
{
  "encounter": {
    "id": 1,
    "met_at": "2026-08-14T10:00:00Z",
    "topic": "ハッカソンで同じチーム",
    "memo": "音声文字起こしのテキスト。Rails が好きらしい。",
    "tags": [
      { "id": 1, "name": "ハッカソン" },
      { "id": 2, "name": "STECH" }
    ],
    "person": { "id": 1, "name": "たなか", "last_encountered_at": "2026-08-14T10:00:00Z" }
  }
}
```

エラー `422 Unprocessable Content`

```json
{ "errors": { "person_name": ["を入力してください"] } }
```

`encounter` キーが無い、または値がオブジェクトでない場合は
`400 Bad Request` を返す。

```json
{ "errors": { "encounter": ["を入力してください"] } }
```

---

## GET /api/v1/people

記録した人の一覧。`last_encountered_at` の降順(最近会った人が先頭)。
同日時の場合は `id` の降順、未接触で `last_encountered_at` が `null` の人物は末尾に並べる。

- MVP ではページネーション・検索パラメータなし。全件返す
- 記録画面の入力補完(名前サジェスト)もこの一覧をクライアント側でフィルタして使う
- `encounters_count` は保存カラムではなく、人物ごとの接触履歴件数をレスポンス生成時に算出する

レスポンス `200 OK`

```json
{
  "people": [
    {
      "id": 1,
      "name": "たなか",
      "note": "",
      "last_encountered_at": "2026-08-14T10:00:00Z",
      "encounters_count": 3
    }
  ]
}
```

---

## GET /api/v1/people/:id

1 人の詳細と接触履歴。履歴は `met_at` の降順、同日時なら `id` の降順。
各接触履歴の `tags` は `name` の昇順で返す。

レスポンス `200 OK`

```json
{
  "person": {
    "id": 1,
    "name": "たなか",
    "note": "Rails 好き。○○大学",
    "last_encountered_at": "2026-08-14T10:00:00Z",
    "encounters": [
      {
        "id": 1,
        "met_at": "2026-08-14T10:00:00Z",
        "topic": "ハッカソンで同じチーム",
        "memo": "…",
        "tags": [{ "id": 1, "name": "ハッカソン" }]
      }
    ]
  }
}
```

---

## PATCH /api/v1/people/:id

名前・メモの事後修正。「曖昧に登録して後から直す」を支える API。

- 更新を受け付けるのは `name` と `note` のみ。それ以外のキーは無視する
- `name` を空文字にしようとした場合は、共通形式の `422 Unprocessable Content` を返す
- `name` と `note` は文字列だけを受け付け、オブジェクト・配列・数値は `422` を返す
- `note: null` はメモを消す操作として受け付け、空文字 `""` に正規化する
- 部分更新は `PATCH` のみを提供し、`PUT` は受け付けない

リクエスト

```json
{ "person": { "name": "田中太郎", "note": "○○大学。Rails 好き" } }
```

レスポンス `200 OK`(GET /api/v1/people/:id と同じ形の `person`、ただし `encounters` は含まない)

```json
{
  "person": { "id": 1, "name": "田中太郎", "note": "○○大学。Rails 好き", "last_encountered_at": "2026-08-14T10:00:00Z" }
}
```

---

## GET /api/v1/tags

タグの一覧。`name` 昇順の全件。記録画面のワンタップチップの候補に使う。
タグの作成 API はない(encounter 作成時の `tag_names` で暗黙に作られる)。

レスポンス `200 OK`

```json
{
  "tags": [
    { "id": 2, "name": "STECH" },
    { "id": 1, "name": "ハッカソン" }
  ]
}
```

---

## GET /api/v1/reminders/today

今日の想起対象(1 人)。日次バッチが生成した reminders を返すだけで、この API 自体は選定しない。

- iOS はアプリ起動時・通知タップ時にこれを叩いて「今日の一人」画面を出す
- 対象がいない日(候補ゼロ・バッチ未実行)は `reminder: null` を返す(404 にはしない)
- 未接触の人物が対象の場合、`person.last_encountered_at` と `person.last_encounter` は `null` を返す

レスポンス `200 OK`

```json
{
  "reminder": {
    "id": 1,
    "remind_on": "2026-08-14",
    "person": {
      "id": 1,
      "name": "たなか",
      "note": "",
      "last_encountered_at": "2026-07-01T10:00:00Z",
      "last_encounter": {
        "met_at": "2026-07-01T10:00:00Z",
        "topic": "ハッカソンで同じチーム",
        "tags": [{ "id": 1, "name": "ハッカソン" }]
      }
    }
  }
}
```

対象がいない日

```json
{ "reminder": null }
```
