# DB 設計

> **状態: 未確定。** 下記は企画時点のラフで、まだマイグレーションは1本も切っていない。
> 実装に入るときにここを先に固めてから `rails g model` する。

## テーブル案

### people

| カラム | 型 | 備考 |
|---|---|---|
| `id` | bigint | |
| `name` | string | あだ名可。曖昧でも登録できることを優先する |
| `note` | text | 自由記述メモ |
| `last_encountered_at` | datetime | 想起バッチの抽出条件に使う |
| `created_at` / `updated_at` | datetime | |

### encounters

| カラム | 型 | 備考 |
|---|---|---|
| `id` | bigint | |
| `person_id` | bigint | FK |
| `met_at` | datetime | |
| `topic` | string | 何を話したか |
| `memo` | text | 音声入力の文字起こしを含む |
| `created_at` / `updated_at` | datetime | |

### tags / encounter_tags

コミュニティやイベントの分類（`#ハッカソン` `#STECH` など）。
Encounter と多対多。

## 未決事項

- `last_encountered_at` を people に非正規化して持つか、encounters から都度引くか
  - 想起バッチが「30日以上会っていない人」を引くので、非正規化しておく方が素直そう
- 音声入力の構造化結果（名前 / トピック / タグ）をどこまで DB に落とすか
- ユーザー（アカウント）の扱い。MVP では単一ユーザー前提で逃げるか
