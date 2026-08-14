require "rails_helper"

RSpec.describe "People API", type: :request do
  describe "GET /api/v1/people" do
    it "接触日時とidの降順で人物と正しい接触回数を返し、未接触の人物を末尾に並べる" do
      older_person = Person.create!(name: "以前会った人", note: "メモ1")
      older_person.encounters.create!(met_at: Time.zone.parse("2026-07-01 12:00:00"))

      same_time = Time.zone.parse("2026-08-12 12:00:00")
      tied_first = Person.create!(name: "同時刻に会った人1", note: "メモ2")
      tied_first.encounters.create!(met_at: same_time)
      tied_second = Person.create!(name: "同時刻に会った人2", note: "メモ3")
      tied_second.encounters.create!(met_at: Time.zone.parse("2026-08-10 12:00:00"))
      tied_second.encounters.create!(met_at: same_time)

      no_encounter_first = Person.create!(name: "未接触の人1")
      no_encounter_second = Person.create!(name: "未接触の人2")

      get "/api/v1/people", as: :json

      expect(response).to have_http_status(:ok)
      created_people = people_in_response(
        tied_second,
        tied_first,
        older_person,
        no_encounter_second,
        no_encounter_first
      )
      expect(created_people).to eq(
        [
          {
            "id" => tied_second.id,
            "name" => "同時刻に会った人2",
            "note" => "メモ3",
            "last_encountered_at" => "2026-08-12T03:00:00Z",
            "encounters_count" => 2
          },
          {
            "id" => tied_first.id,
            "name" => "同時刻に会った人1",
            "note" => "メモ2",
            "last_encountered_at" => "2026-08-12T03:00:00Z",
            "encounters_count" => 1
          },
          {
            "id" => older_person.id,
            "name" => "以前会った人",
            "note" => "メモ1",
            "last_encountered_at" => "2026-07-01T03:00:00Z",
            "encounters_count" => 1
          },
          {
            "id" => no_encounter_second.id,
            "name" => "未接触の人2",
            "note" => "",
            "last_encountered_at" => nil,
            "encounters_count" => 0
          },
          {
            "id" => no_encounter_first.id,
            "name" => "未接触の人1",
            "note" => "",
            "last_encountered_at" => nil,
            "encounters_count" => 0
          }
        ]
      )
    end

    it "人物数にかかわらず1回のSELECTで一覧と接触回数を取得する" do
      Person.create!(name: "クエリ確認1")

      expect(capture_select_queries { get "/api/v1/people", as: :json }.size).to eq(1)

      3.times do |index|
        person = Person.create!(name: "クエリ確認#{index + 2}")
        person.encounters.create!(met_at: Time.zone.parse("2026-08-14 19:00:00"))
      end

      expect(capture_select_queries { get "/api/v1/people", as: :json }.size).to eq(1)
    end
  end

  describe "GET /api/v1/people/:id" do
    it "接触履歴をmet_atとidの降順、各履歴のタグをnameの昇順で返す" do
      person = Person.create!(name: "たなか", note: "Rails 好き。○○大学")
      tag_b = Tag.create!(name: "表示順B")
      tag_a = Tag.create!(name: "表示順A")
      tag_c = Tag.create!(name: "表示順C")
      older_encounter = person.encounters.create!(
        met_at: Time.zone.parse("2026-07-01 12:00:00"),
        topic: "初顔合わせ",
        memo: nil
      )
      older_encounter.tags << tag_c

      same_time = Time.zone.parse("2026-08-14 19:00:00")
      tied_first = person.encounters.create!(
        met_at: same_time,
        topic: "同時刻の履歴1",
        memo: "複数タグ"
      )
      tied_first.tags << tag_b
      tied_first.tags << tag_a
      tied_second = person.encounters.create!(
        met_at: same_time,
        topic: "同時刻の履歴2",
        memo: "後から保存"
      )
      tied_second.tags << tag_a

      get "/api/v1/people/#{person.id}", as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "person" => {
          "id" => person.id,
          "name" => "たなか",
          "note" => "Rails 好き。○○大学",
          "last_encountered_at" => "2026-08-14T10:00:00Z",
          "encounters" => [
            {
              "id" => tied_second.id,
              "met_at" => "2026-08-14T10:00:00Z",
              "topic" => "同時刻の履歴2",
              "memo" => "後から保存",
              "tags" => [ { "id" => tag_a.id, "name" => "表示順A" } ]
            },
            {
              "id" => tied_first.id,
              "met_at" => "2026-08-14T10:00:00Z",
              "topic" => "同時刻の履歴1",
              "memo" => "複数タグ",
              "tags" => [
                { "id" => tag_a.id, "name" => "表示順A" },
                { "id" => tag_b.id, "name" => "表示順B" }
              ]
            },
            {
              "id" => older_encounter.id,
              "met_at" => "2026-07-01T03:00:00Z",
              "topic" => "初顔合わせ",
              "memo" => nil,
              "tags" => [ { "id" => tag_c.id, "name" => "表示順C" } ]
            }
          ]
        }
      )
    end

    it "存在しないidなら404を返す" do
      get "/api/v1/people/0", as: :json

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq("errors" => { "base" => [ "not found" ] })
    end
  end

  describe "PATCH /api/v1/people/:id" do
    it "nameとnoteを更新する" do
      person = Person.create!(name: "たなか", note: "")

      patch "/api/v1/people/#{person.id}", params: {
        person: { name: "田中太郎", note: "○○大学。Rails 好き" }
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "person" => {
          "id" => person.id,
          "name" => "田中太郎",
          "note" => "○○大学。Rails 好き",
          "last_encountered_at" => nil
        }
      )
      expect(person.reload).to have_attributes(name: "田中太郎", note: "○○大学。Rails 好き")
    end

    it "noteがnullなら空文字に更新する" do
      person = Person.create!(name: "たなか", note: "削除するメモ")

      patch "/api/v1/people/#{person.id}", params: { person: { note: nil } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("person", "note")).to eq("")
      expect(person.reload.note).to eq("")
    end

    it "nameが空文字なら422を返す" do
      person = Person.create!(name: "たなか")

      patch "/api/v1/people/#{person.id}", params: { person: { name: "" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq("errors" => { "name" => [ "を入力してください" ] })
      expect(person.reload.name).to eq("たなか")
    end

    [
      [ "nameがオブジェクト", :name, { value: "田中" } ],
      [ "nameが配列", :name, [ "田中" ] ],
      [ "noteが数値", :note, 123 ]
    ].each do |description, attribute, value|
      it "#{description}なら422を返す" do
        person = Person.create!(name: "たなか", note: "変更前")

        patch "/api/v1/people/#{person.id}", params: {
          person: { attribute => value }
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body).to eq(
          "errors" => { attribute.to_s => [ "は不正な値です" ] }
        )
        expect(person.reload).to have_attributes(name: "たなか", note: "変更前")
      end
    end

    it "許可外のキーを無視する" do
      person = Person.create!(name: "たなか")
      encountered_at = Time.zone.parse("2026-08-14 19:00:00")
      person.update_columns(last_encountered_at: encountered_at)

      patch "/api/v1/people/#{person.id}", params: {
        person: { name: "田中太郎", last_encountered_at: "2020-01-01T00:00:00Z" }
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(person.reload).to have_attributes(name: "田中太郎", last_encountered_at: encountered_at)
      expect(response.parsed_body.dig("person", "last_encountered_at")).to eq("2026-08-14T10:00:00Z")
    end

    it "personキーがなければ共通形式の400を返す" do
      person = Person.create!(name: "たなか")

      patch "/api/v1/people/#{person.id}", params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq("errors" => { "person" => [ "を入力してください" ] })
    end

    it "personがオブジェクトでなければ共通形式の400を返す" do
      person = Person.create!(name: "たなか")

      patch "/api/v1/people/#{person.id}", params: { person: "不正" }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq("errors" => { "person" => [ "を入力してください" ] })
    end

    it "存在しないidなら404を返す" do
      patch "/api/v1/people/0", params: { person: { name: "田中太郎" } }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq("errors" => { "base" => [ "not found" ] })
    end
  end

  it "PUTの更新ルートを公開しない" do
    expect do
      Rails.application.routes.recognize_path("/api/v1/people/1", method: :put)
    end.to raise_error(ActionController::RoutingError)
  end

  def people_in_response(*people)
    ids = people.map(&:id)
    response.parsed_body.fetch("people").select { |person| ids.include?(person.fetch("id")) }
  end

  def capture_select_queries
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      sql = payload.fetch(:sql)
      queries << sql if sql.start_with?("SELECT")
    end

    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
