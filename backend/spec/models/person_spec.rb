require "rails_helper"

RSpec.describe Person, type: :model do
  describe "バリデーション" do
    let(:person) { described_class.new(name: name) }

    context "名前が空の場合" do
      let(:name) { "" }

      it "保存できない" do
        expect(person).not_to be_valid
        expect(person.errors.of_kind?(:name, :blank)).to be(true)
      end
    end

    context "名前が入力されている場合" do
      let(:name) { "あだ名" }

      it "名前以外は未入力でも保存できる" do
        expect(person).to be_valid
        expect(person.note).to eq("")
      end
    end
  end
end
