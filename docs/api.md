# API 仕様

> **状態: 未確定。** まだ1本も実装していない。
> エンドポイントを足すたびにここを更新し、iOS 側との認識ズレを防ぐ。

ベース URL

| 環境 | URL |
|---|---|
| ローカル | `http://localhost:3000` |

現状 Rails 標準のヘルスチェックだけが生きている。

## GET /up

Rails 組み込み。アプリが起動していれば 200、起動時例外があれば 500。

```bash
curl -i http://localhost:3000/up
```

## 実装予定

MVP スコープに合わせて以下から着手する。

| メソッド | パス | 用途 |
|---|---|---|
| `POST` | `/api/v1/encounters` | 出会いの記録（音声 or ワンタップ） |
| `GET` | `/api/v1/people` | 記録した人の一覧 |
| `GET` | `/api/v1/people/:id` | 1人の詳細と接触履歴 |

## 記述フォーマット

エンドポイントを足すときはこの粒度で書く。

````markdown
## POST /api/v1/encounters

リクエスト

```json
{ "encounter": { "person_name": "たなか", "met_at": "2026-08-14T19:00:00+09:00", "topic": "ハッカソンで同じチーム" } }
```

レスポンス `201 Created`

```json
{ "id": 1, "person": { "id": 1, "name": "たなか" }, "met_at": "..." }
```

エラー `422 Unprocessable Entity`

```json
{ "errors": { "person_name": ["can't be blank"] } }
```
````
