require "rails_helper"

RSpec.describe EncounterTag, type: :model do
  it "EncounterとTagを関連付ける" do
    person = Person.create!(name: "あおいさん")
    encounter = Encounter.create!(person: person, met_at: Time.zone.parse("2026-08-10 12:00:00"))
    tag = Tag.create!(name: "RSpec関連確認用")

    described_class.create!(encounter: encounter, tag: tag)

    expect(encounter.reload.tags).to contain_exactly(tag)
    expect(tag.reload.encounters).to contain_exactly(encounter)
  end

  it "同じ組み合わせを重複して保存できない" do
    person = Person.create!(name: "あおいさん")
    encounter = Encounter.create!(person: person, met_at: Time.zone.parse("2026-08-10 12:00:00"))
    tag = Tag.create!(name: "RSpec重複関連確認用")
    described_class.create!(encounter: encounter, tag: tag)

    expect do
      described_class.create!(encounter: encounter, tag: tag)
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
