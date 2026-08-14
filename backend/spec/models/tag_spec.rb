require "rails_helper"

RSpec.describe Tag, type: :model do
  describe "バリデーション" do
    it "名前が空なら保存できない" do
      tag = described_class.new(name: "")

      expect(tag).not_to be_valid
      expect(tag.errors.of_kind?(:name, :blank)).to be(true)
    end

    it "同じ名前を重複して保存できない" do
      described_class.create!(name: "RSpec重複確認用")
      duplicate = described_class.new(name: "RSpec重複確認用")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors.of_kind?(:name, :taken)).to be(true)
    end
  end
end
