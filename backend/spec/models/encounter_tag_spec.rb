require "rails_helper"

RSpec.describe EncounterTag, type: :model do
  let(:person) { Person.create!(name: "あおいさん") }
  let(:encounter) { Encounter.create!(person: person, met_at: Time.zone.parse("2026-08-10 12:00:00")) }
  let(:tag) { Tag.create!(name: "RSpec関連確認用") }
  let(:encounter_tag) { described_class.create!(encounter: encounter, tag: tag) }
  let(:duplicate_encounter_tag) { described_class.create!(encounter: encounter, tag: tag) }

  it "EncounterとTagを関連付ける" do
    encounter_tag

    expect(encounter.reload.tags).to contain_exactly(tag)
    expect(tag.reload.encounters).to contain_exactly(encounter)
  end

  it "同じ組み合わせを重複して保存できない" do
    encounter_tag

    expect { duplicate_encounter_tag }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
