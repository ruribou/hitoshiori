require "rails_helper"

RSpec.describe Encounter, type: :model do
  let(:person) { Person.create!(name: "あおいさん") }
  let(:met_at) { Time.zone.parse("2026-08-10 12:00:00") }

  describe "バリデーション" do
    let(:encounter) { described_class.new(person: person) }

    it "会った日時が空なら保存できない" do
      expect(encounter).not_to be_valid
      expect(encounter.errors.of_kind?(:met_at, :blank)).to be(true)
    end
  end

  describe "人物の最終接触日時の再計算" do
    let(:encounter) { described_class.create!(person: person, met_at: met_at) }
    let(:older_encounter) { described_class.create!(person: person, met_at: met_at - 1.month) }

    it "作成時に最終接触日時を更新する" do
      encounter

      expect(person.reload.last_encountered_at).to eq(met_at)
    end

    it "古い記録を後から追加しても最終接触日時を巻き戻さない" do
      encounter
      older_encounter

      expect(person.reload.last_encountered_at).to eq(met_at)
    end

    it "再計算前に人物を行ロックする" do
      person
      expect(Person).to receive(:lock).with("FOR NO KEY UPDATE").and_call_original

      encounter
    end

    it "削除後に残った記録から最終接触日時を再計算する" do
      older_encounter
      encounter.destroy!

      expect(person.reload.last_encountered_at).to eq(older_encounter.met_at)
    end

    it "全て削除したら最終接触日時をnilに戻す" do
      encounter.destroy!

      expect(person.reload.last_encountered_at).to be_nil
    end
  end
end
