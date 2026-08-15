require "rails_helper"

RSpec.describe Reminder, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:reference_time) { Time.zone.local(2026, 8, 15, 6, 0, 0) }

  around do |example|
    travel_to(reference_time) { example.run }
  end

  before do
    described_class.delete_all
    EncounterTag.delete_all
    Encounter.delete_all
    Tag.delete_all
    Person.delete_all
  end

  describe ".create_for_today!" do
    let(:oldest_person) { person_with_last_encounter("いちばん久しぶりの人", reference_time - 60.days) }
    let(:next_person) { person_with_last_encounter("次に久しぶりの人", reference_time - 45.days) }
    let(:boundary_person) { person_with_last_encounter("30日前の人", reference_time - 30.days) }
    let(:recent_person) { person_with_last_encounter("29日前の人", reference_time - 29.days) }
    let(:recent_reminder) do
      described_class.create!(person: oldest_person, remind_on: Date.current - 7.days)
    end

    it "いちばん会っていない候補を選ぶ" do
      oldest_person
      next_person

      reminder = described_class.create_for_today!

      expect(reminder).to have_attributes(person: oldest_person, remind_on: Date.current)
    end

    it "ちょうど30日前の人を候補に含め、29日前の人を候補から除外する" do
      boundary_person
      recent_person

      reminder = described_class.create_for_today!

      expect(reminder.person).to eq(boundary_person)
    end

    it "直近30日で想起した人を除外して次の候補を選ぶ" do
      next_person
      recent_reminder

      reminder = described_class.create_for_today!

      expect(reminder.person).to eq(next_person)
    end

    it "候補がなければReminderを作らない" do
      recent_person
      reminder = nil

      expect { reminder = described_class.create_for_today! }.not_to change(described_class, :count)
      expect(reminder).to be_nil
    end
  end

  def person_with_last_encounter(name, last_encountered_at)
    Person.create!(name: name).tap do |person|
      person.update_columns(last_encountered_at: last_encountered_at)
    end
  end
end
