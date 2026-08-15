require "rails_helper"

RSpec.describe "GET /api/v1/tags", type: :request do
  let!(:tag_b) { Tag.create!(name: "一覧表示順B") }
  let!(:tag_a) { Tag.create!(name: "一覧表示順A") }

  it "nameの昇順で全タグを返す" do
    get "/api/v1/tags", as: :json

    expect(response).to have_http_status(:ok)
    created_tags = response.parsed_body.fetch("tags").select do |tag|
      [ tag_a.id, tag_b.id ].include?(tag.fetch("id"))
    end
    expect(created_tags).to eq(
      [
        { "id" => tag_a.id, "name" => "一覧表示順A" },
        { "id" => tag_b.id, "name" => "一覧表示順B" }
      ]
    )
  end
end
