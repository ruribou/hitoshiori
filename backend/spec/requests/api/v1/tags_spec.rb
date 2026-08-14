require "rails_helper"

RSpec.describe "GET /api/v1/tags", type: :request do
  before do
    EncounterTag.delete_all
    Tag.delete_all
  end

  it "nameの昇順で全タグを返す" do
    hackathon = Tag.create!(name: "ハッカソン")
    stech = Tag.create!(name: "STECH")

    get "/api/v1/tags", as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(
      "tags" => [
        { "id" => stech.id, "name" => "STECH" },
        { "id" => hackathon.id, "name" => "ハッカソン" }
      ]
    )
  end
end
