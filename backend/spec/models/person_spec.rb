require "rails_helper"

RSpec.describe Person, type: :model do
  describe "バリデーション" do
    it "名前が空なら保存できない" do
      person = described_class.new(name: "")

      expect(person).not_to be_valid
      expect(person.errors.of_kind?(:name, :blank)).to be(true)
    end

    it "名前以外は未入力でも保存できる" do
      person = described_class.new(name: "あだ名")

      expect(person).to be_valid
      expect(person.note).to eq("")
    end
  end
end
