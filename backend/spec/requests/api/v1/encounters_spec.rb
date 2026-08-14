require "rails_helper"

RSpec.describe "POST /api/v1/encounters", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  subject(:request_encounter) do
    post "/api/v1/encounters", params: { encounter: encounter_params }, as: :json
  end

  let(:encounter_params) do
    {
      person_name: "たなか",
      met_at: "2026-08-14T19:00:00+09:00",
      topic: "ハッカソンで同じチーム",
      memo: "音声文字起こしのテキスト。Rails が好きらしい。",
      tag_names: [ "ハッカソン", "STECH" ]
    }
  end

  it "新しい人物と出会いを作り、仕様どおりのJSONを返す" do
    expect { request_encounter }.to change(Person, :count).by(1).and change(Encounter, :count).by(1)

    expect(response).to have_http_status(:created)

    encounter = Encounter.last
    person = encounter.person
    tags = encounter.tags.index_by(&:name)

    expect(response.parsed_body).to eq(
      "encounter" => {
        "id" => encounter.id,
        "met_at" => "2026-08-14T10:00:00Z",
        "topic" => "ハッカソンで同じチーム",
        "memo" => "音声文字起こしのテキスト。Rails が好きらしい。",
        "tags" => [
          { "id" => tags.fetch("ハッカソン").id, "name" => "ハッカソン" },
          { "id" => tags.fetch("STECH").id, "name" => "STECH" }
        ],
        "person" => {
          "id" => person.id,
          "name" => "たなか",
          "last_encountered_at" => "2026-08-14T10:00:00Z"
        }
      }
    )
    expect(person.last_encountered_at).to eq(Time.zone.parse("2026-08-14 19:00:00"))
  end

  it "既存人物へ出会いを追加し、人物を増やさない" do
    person = Person.create!(name: "既存の人")
    encounter_params[:person_id] = person.id
    encounter_params.delete(:person_name)

    expect { request_encounter }.not_to change(Person, :count)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("encounter", "person", "id")).to eq(person.id)
    expect(person.reload.encounters.count).to eq(1)
    expect(person.last_encountered_at).to eq(Time.zone.parse("2026-08-14 19:00:00"))
  end

  it "person_idとperson_nameの両方があれば既存人物を優先する" do
    person = Person.create!(name: "既存の人")
    encounter_params[:person_id] = person.id
    encounter_params[:person_name] = "新しい人"

    expect { request_encounter }.not_to change(Person, :count)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("encounter", "person", "id")).to eq(person.id)
  end

  it "同じperson_nameでも投稿ごとに別の人物を作る" do
    expect do
      2.times do
        post "/api/v1/encounters", params: { encounter: encounter_params }, as: :json
      end
    end.to change(Person.where(name: "たなか"), :count).by(2)

    expect(response).to have_http_status(:created)
  end

  it "タグ名を正規化し、新しいタグの作成と既存タグの再利用を行う" do
    existing_tag = Tag.find_or_create_by!(name: "STECH")
    encounter_params[:tag_names] = [ " 初対面 ", "", "STECH", "初対面", "   " ]

    expect { request_encounter }.to change(Tag, :count).by(1)

    expect(response).to have_http_status(:created)
    encounter = Encounter.last
    expect(encounter.tags).to contain_exactly(existing_tag, Tag.find_by!(name: "初対面"))
    expect(response.parsed_body.dig("encounter", "tags")).to eq(
      [
        { "id" => Tag.find_by!(name: "初対面").id, "name" => "初対面" },
        { "id" => existing_tag.id, "name" => "STECH" }
      ]
    )
  end

  it "met_atを省略すると現在時刻を使う" do
    encounter_params.delete(:met_at)

    travel_to(Time.zone.parse("2026-08-14 21:30:00")) do
      request_encounter
    end

    expect(response).to have_http_status(:created)
    expect(Encounter.last.met_at).to eq(Time.zone.parse("2026-08-14 21:30:00"))
    expect(response.parsed_body.dig("encounter", "met_at")).to eq("2026-08-14T12:30:00Z")
  end

  it "person_idとperson_nameの両方がなければ422を返す" do
    encounter_params.delete(:person_name)

    expect { request_encounter }.not_to change(Person, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to eq("errors" => { "person_name" => [ "を入力してください" ] })
  end

  it "存在しないperson_idなら404を返す" do
    encounter_params.delete(:person_name)
    encounter_params[:person_id] = 0

    expect { request_encounter }.not_to change(Encounter, :count)

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body).to eq("errors" => { "base" => [ "not found" ] })
  end

  it "出会いの保存に失敗したら新しい人物も残さない" do
    encounter_params[:met_at] = "不正な日時"

    expect { request_encounter }.not_to change(Person, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.fetch("errors")).to include("met_at")
  end
end
