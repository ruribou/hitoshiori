require "rails_helper"

RSpec.describe Tag, type: :model do
  describe "バリデーション" do
    let(:tag) { described_class.new(name: name) }

    context "名前が空の場合" do
      let(:name) { "" }

      it "保存できない" do
        expect(tag).not_to be_valid
        expect(tag.errors.of_kind?(:name, :blank)).to be(true)
      end
    end

    context "同じ名前が保存済みの場合" do
      let(:name) { "RSpec重複確認用" }
      let(:existing_tag) { described_class.create!(name: name) }

      it "重複して保存できない" do
        existing_tag

        expect(tag).not_to be_valid
        expect(tag.errors.of_kind?(:name, :taken)).to be(true)
      end
    end
  end
end
