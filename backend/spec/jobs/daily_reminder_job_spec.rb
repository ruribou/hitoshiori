require "rails_helper"

RSpec.describe DailyReminderJob, type: :job do
  include ActiveSupport::Testing::TimeHelpers

  let(:reference_time) { Time.zone.local(2026, 8, 15, 6, 0, 0) }
  let(:eligible_person) { Person.create!(name: "候補の人") }
  let(:next_eligible_person) { Person.create!(name: "次の候補の人") }
  let(:recent_person) { Person.create!(name: "最近会った人") }

  around do |example|
    travel_to(reference_time) { example.run }
  end

  before do
    Reminder.delete_all
    EncounterTag.delete_all
    Encounter.delete_all
    Tag.delete_all
    Person.delete_all
    eligible_person.update_columns(last_encountered_at: reference_time - 60.days)
    next_eligible_person.update_columns(last_encountered_at: reference_time - 45.days)
    recent_person.update_columns(last_encountered_at: reference_time - 29.days)
  end

  it "同日に2回実行してもReminderを1件だけ作る" do
    described_class.perform_now
    described_class.perform_now

    expect(Reminder.where(remind_on: Date.current)).to contain_exactly(
      have_attributes(person: eligible_person, remind_on: Date.current)
    )
  end

  it "候補がなければ正常終了する" do
    eligible_person.update_columns(last_encountered_at: reference_time - 29.days)
    next_eligible_person.update_columns(last_encountered_at: reference_time - 29.days)

    expect { described_class.perform_now }.not_to change(Reminder, :count)
  end
end
