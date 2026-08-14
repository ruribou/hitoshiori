require "rails_helper"

RSpec.describe "People API", type: :request do
  before do
    EncounterTag.delete_all
    Encounter.delete_all
    Person.delete_all
    Tag.delete_all
  end

  describe "GET /api/v1/people" do
    it "last_encountered_atの降順で人物と正しい接触回数を返す" do
      older_person = Person.create!(name: "以前会った人", note: "メモ1")
      older_person.encounters.create!(met_at: Time.zone.parse("2026-07-01 12:00:00"))

      recent_person = Person.create!(name: "最近会った人", note: "メモ2")
      recent_person.encounters.create!(met_at: Time.zone.parse("2026-08-10 12:00:00"))
      recent_person.encounters.create!(met_at: Time.zone.parse("2026-08-12 12:00:00"))

      person_without_encounters = Person.create!(name: "まだ会っていない人")

      get "/api/v1/people", as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "people" => [
          {
            "id" => recent_person.id,
            "name" => "最近会った人",
            "note" => "メモ2",
            "last_encountered_at" => "2026-08-12T03:00:00Z",
            "encounters_count" => 2
          },
          {
            "id" => older_person.id,
            "name" => "以前会った人",
            "note" => "メモ1",
            "last_encountered_at" => "2026-07-01T03:00:00Z",
            "encounters_count" => 1
          },
          {
            "id" => person_without_encounters.id,
            "name" => "まだ会っていない人",
            "note" => "",
            "last_encountered_at" => nil,
            "encounters_count" => 0
          }
        ]
      )
    end
  end

  describe "GET /api/v1/people/:id" do
    it "接触履歴をmet_atの降順でタグとともに返す" do
      person = Person.create!(name: "たなか", note: "Rails 好き。○○大学")
      hackathon = Tag.create!(name: "ハッカソン")
      stech = Tag.create!(name: "STECH")
      older_encounter = person.encounters.create!(
        met_at: Time.zone.parse("2026-07-01 12:00:00"),
        topic: "初顔合わせ",
        memo: nil
      )
      older_encounter.tags << stech
      recent_encounter = person.encounters.create!(
        met_at: Time.zone.parse("2026-08-14 19:00:00"),
        topic: "ハッカソンで同じチーム",
        memo: "Rails が好きらしい。"
      )
      recent_encounter.tags << hackathon

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
              "id" => recent_encounter.id,
              "met_at" => "2026-08-14T10:00:00Z",
              "topic" => "ハッカソンで同じチーム",
              "memo" => "Rails が好きらしい。",
              "tags" => [ { "id" => hackathon.id, "name" => "ハッカソン" } ]
            },
            {
              "id" => older_encounter.id,
              "met_at" => "2026-07-01T03:00:00Z",
              "topic" => "初顔合わせ",
              "memo" => nil,
              "tags" => [ { "id" => stech.id, "name" => "STECH" } ]
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

    it "nameが空文字なら422を返す" do
      person = Person.create!(name: "たなか")

      patch "/api/v1/people/#{person.id}", params: { person: { name: "" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq("errors" => { "name" => [ "を入力してください" ] })
      expect(person.reload.name).to eq("たなか")
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

    it "存在しないidなら404を返す" do
      patch "/api/v1/people/0", params: { person: { name: "田中太郎" } }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq("errors" => { "base" => [ "not found" ] })
    end
  end
end
