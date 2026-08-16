require "rails_helper"

RSpec.describe "DELETE /api/v1/encounters/:id", type: :request do
  subject(:delete_encounter) do
    delete "/api/v1/encounters/#{target_encounter.id}", params: request_params, as: :json
  end

  let(:person) { Person.create!(name: "たなか") }
  let(:older_encounter) do
    person.encounters.create!(met_at: Time.zone.parse("2026-08-01 19:00:00"))
  end
  let(:latest_encounter) do
    person.encounters.create!(met_at: Time.zone.parse("2026-08-14 19:00:00"))
  end
  let(:tag) { Tag.create!(name: "ハッカソン") }
  let(:target_encounter) { latest_encounter }
  let(:request_params) { {} }

  it "既存人物への追記を削除し、最終接触日を残りの履歴から再計算する" do
    older_encounter
    latest_encounter.tags << tag

    expect { delete_encounter }.to change(Encounter, :count).by(-1)

    expect(response).to have_http_status(:no_content)
    expect(person.reload.last_encountered_at).to eq(Time.zone.parse("2026-08-01 19:00:00"))
    expect(Tag.find_by(id: tag.id)).to eq(tag)
  end

  context "新規人物だけが残る記録を取り消す場合" do
    let(:target_encounter) do
      Person.create!(name: "新しい人").encounters.create!(met_at: Time.zone.parse("2026-08-14 19:00:00"))
    end
    let(:request_params) { { remove_empty_person: true } }
    let(:target_person) { target_encounter.person }

    it "空になった人物も削除する" do
      target_person

      expect { delete_encounter }.to change(Person, :count).by(-1).and change(Encounter, :count).by(-1)

      expect(response).to have_http_status(:no_content)
      expect(Person.find_by(id: target_person.id)).to be_nil
    end
  end

  it "存在しない記録は共通形式の404を返す" do
    delete "/api/v1/encounters/0", as: :json

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body).to eq("errors" => { "base" => [ "not found" ] })
  end
end
