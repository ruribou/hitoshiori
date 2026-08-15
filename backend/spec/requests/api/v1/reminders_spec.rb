require "rails_helper"

RSpec.describe "Reminders API", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:reference_time) { Time.zone.local(2026, 8, 15, 6, 0, 0) }
  let(:person) { Person.create!(name: "たなか", note: "Rails 好き。○○大学") }
  let(:older_encounter) do
    person.encounters.create!(
      met_at: Time.zone.parse("2026-07-01 12:00:00"),
      topic: "初顔合わせ"
    )
  end
  let(:latest_encounter) do
    person.encounters.create!(
      met_at: Time.zone.parse("2026-07-15 12:00:00"),
      topic: "ハッカソンで同じチーム"
    )
  end
  let(:tag) { Tag.create!(name: "想起API用タグ") }
  let(:reminder) do
    latest_encounter.tags << tag
    older_encounter
    Reminder.create!(person: person, remind_on: Date.current)
  end

  around do |example|
    travel_to(reference_time) { example.run }
  end

  describe "GET /api/v1/reminders/today" do
    it "当日の想起対象と人物の最新接触を返す" do
      reminder

      get "/api/v1/reminders/today", as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "reminder" => {
          "id" => reminder.id,
          "remind_on" => "2026-08-15",
          "person" => {
            "id" => person.id,
            "name" => "たなか",
            "note" => "Rails 好き。○○大学",
            "last_encountered_at" => "2026-07-15T03:00:00Z",
            "last_encounter" => {
              "met_at" => "2026-07-15T03:00:00Z",
              "topic" => "ハッカソンで同じチーム",
              "tags" => [ { "id" => tag.id, "name" => "想起API用タグ" } ]
            }
          }
        }
      )
    end

    it "当日の想起対象がなければnullを返す" do
      get "/api/v1/reminders/today", as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("reminder" => nil)
    end
  end
end
