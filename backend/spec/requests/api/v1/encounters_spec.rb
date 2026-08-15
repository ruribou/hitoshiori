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
  let(:person) { Person.create!(name: "既存の人") }
  let(:existing_tag) { Tag.find_or_create_by!(name: "STECH") }
  let(:created_encounter) { Encounter.last }
  let(:created_person) { created_encounter.person }
  let(:created_tags) { created_encounter.tags.index_by(&:name) }
  let(:conflicting_tag) { Tag.create!(name: "競合タグ") }
  let(:invalid_person) { Person.new.tap(&:validate) }
  let(:record_invalid_error) { ActiveRecord::RecordInvalid.new(invalid_person) }

  it "新しい人物と出会いを作り、仕様どおりのJSONを返す" do
    expect { request_encounter }.to change(Person, :count).by(1).and change(Encounter, :count).by(1)

    expect(response).to have_http_status(:created)

    expect(response.parsed_body).to eq(
      "encounter" => {
        "id" => created_encounter.id,
        "met_at" => "2026-08-14T10:00:00Z",
        "topic" => "ハッカソンで同じチーム",
        "memo" => "音声文字起こしのテキスト。Rails が好きらしい。",
        "tags" => [
          { "id" => created_tags.fetch("ハッカソン").id, "name" => "ハッカソン" },
          { "id" => created_tags.fetch("STECH").id, "name" => "STECH" }
        ],
        "person" => {
          "id" => created_person.id,
          "name" => "たなか",
          "last_encountered_at" => "2026-08-14T10:00:00Z"
        }
      }
    )
    expect(created_person.last_encountered_at).to eq(Time.zone.parse("2026-08-14 19:00:00"))
  end

  it "既存人物へ出会いを追加し、人物を増やさない" do
    encounter_params[:person_id] = person.id
    encounter_params.delete(:person_name)

    expect { request_encounter }.not_to change(Person, :count)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("encounter", "person", "id")).to eq(person.id)
    expect(person.reload.encounters.count).to eq(1)
    expect(person.last_encountered_at).to eq(Time.zone.parse("2026-08-14 19:00:00"))
  end

  it "person_idとperson_nameの両方があれば既存人物を優先する" do
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
    existing_tag
    encounter_params[:tag_names] = [ " 初対面 ", "", "STECH", "初対面", "   " ]

    expect { request_encounter }.to change(Tag, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(created_encounter.tags).to contain_exactly(existing_tag, Tag.find_by!(name: "初対面"))
    expect(response.parsed_body.dig("encounter", "tags")).to eq(
      [
        { "id" => Tag.find_by!(name: "初対面").id, "name" => "初対面" },
        { "id" => existing_tag.id, "name" => "STECH" }
      ]
    )
  end

  {
    "未指定" => :omitted,
    "null" => nil,
    "空文字" => ""
  }.each do |description, value|
    it "met_atが#{description}なら現在時刻を使う" do
      if value == :omitted
        encounter_params.delete(:met_at)
      else
        encounter_params[:met_at] = value
      end

      travel_to(Time.zone.parse("2026-08-14 21:30:00")) do
        request_encounter
      end

      expect(response).to have_http_status(:created)
      expect(Encounter.last.met_at).to eq(Time.zone.parse("2026-08-14 21:30:00"))
      expect(response.parsed_body.dig("encounter", "met_at")).to eq("2026-08-14T12:30:00Z")
    end
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

  it "encounterキーがなければ共通形式の400を返す" do
    post "/api/v1/encounters", params: {}, as: :json

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body).to eq("errors" => { "encounter" => [ "を入力してください" ] })
  end

  it "encounterがオブジェクトでなければ共通形式の400を返す" do
    post "/api/v1/encounters", params: { encounter: "不正" }, as: :json

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body).to eq("errors" => { "encounter" => [ "を入力してください" ] })
  end

  it "tag_namesが配列でなければ日本語の422を返す" do
    encounter_params[:tag_names] = "ハッカソン"

    expect { request_encounter }.not_to change(Person, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to eq("errors" => { "tag_names" => [ "は不正な値です" ] })
  end

  it "tag_namesに文字列以外が含まれていれば日本語の422を返す" do
    encounter_params[:tag_names] = [ "ハッカソン", 1 ]

    expect { request_encounter }.not_to change(Person, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to eq("errors" => { "tag_names" => [ "は不正な値です" ] })
  end

  it "タグの一意制約と競合しても既存タグを再利用する" do
    encounter_params[:tag_names] = [ "競合タグ" ]
    allow(Tag).to receive(:insert_all).and_wrap_original do |original, rows, **options|
      conflicting_tag
      original.call(rows, **options)
    end

    expect { request_encounter }.to change(Tag.where(name: "競合タグ"), :count).by(1)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("encounter", "tags")).to eq(
      [ { "id" => Tag.find_by!(name: "競合タグ").id, "name" => "競合タグ" } ]
    )
  end

  it "タグ数にかかわらずタグと中間テーブルを一括で処理する" do
    encounter_params[:tag_names] = %w[タグ1 タグ2 タグ3 タグ4 タグ5]
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      queries << payload.fetch(:sql)
    end

    begin
      request_encounter
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    expect(response).to have_http_status(:created)
    expect(queries.grep(/\A(?:SELECT|INSERT).*"tags"/).size).to eq(2)
    expect(queries.grep(/\AINSERT.*"encounter_tags"/).size).to eq(1)
  end

  it "出会いの保存に失敗したら新しい人物も残さない" do
    encounter_params[:met_at] = "不正な日時"

    expect { request_encounter }.not_to change(Person, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to eq("errors" => { "met_at" => [ "は不正な値です" ] })
  end

  it "想定外のモデル保存失敗を422として扱わない" do
    allow(Person).to receive(:create!).and_raise(record_invalid_error)

    request_encounter

    expect(response).to have_http_status(:internal_server_error)
  end
end
