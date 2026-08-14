require "rails_helper"

RSpec.describe Encounter, type: :model do
  let(:person) { Person.create!(name: "あおいさん") }

  describe "バリデーション" do
    it "会った日時が空なら保存できない" do
      encounter = described_class.new(person: person)

      expect(encounter).not_to be_valid
      expect(encounter.errors.of_kind?(:met_at, :blank)).to be(true)
    end
  end

  describe "人物の最終接触日時の再計算" do
    it "作成時に最終接触日時を更新する" do
      met_at = Time.zone.parse("2026-08-10 12:00:00")

      described_class.create!(person: person, met_at: met_at)

      expect(person.reload.last_encountered_at).to eq(met_at)
    end

    it "古い記録を後から追加しても最終接触日時を巻き戻さない" do
      latest_met_at = Time.zone.parse("2026-08-10 12:00:00")
      described_class.create!(person: person, met_at: latest_met_at)

      described_class.create!(person: person, met_at: latest_met_at - 1.month)

      expect(person.reload.last_encountered_at).to eq(latest_met_at)
    end

    it "再計算前に人物を行ロックする" do
      person
      expect(Person).to receive(:lock).with("FOR NO KEY UPDATE").and_call_original

      described_class.create!(person: person, met_at: Time.zone.parse("2026-08-10 12:00:00"))
    end

    it "削除後に残った記録から最終接触日時を再計算する" do
      older = described_class.create!(person: person, met_at: Time.zone.parse("2026-07-01 12:00:00"))
      latest = described_class.create!(person: person, met_at: Time.zone.parse("2026-08-10 12:00:00"))

      latest.destroy!

      expect(person.reload.last_encountered_at).to eq(older.met_at)
    end

    it "全て削除したら最終接触日時をnilに戻す" do
      encounter = described_class.create!(person: person, met_at: Time.zone.parse("2026-08-10 12:00:00"))

      encounter.destroy!

      expect(person.reload.last_encountered_at).to be_nil
    end
  end
end
