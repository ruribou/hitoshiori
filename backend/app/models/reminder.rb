class Reminder < ApplicationRecord
  INACTIVITY_PERIOD = 30.days
  RECENT_REMINDER_EXCLUSION_PERIOD = 30.days

  belongs_to :person

  def self.create_for_today!
    person = eligible_people.first
    create!(person: person, remind_on: Date.current) if person
  end

  def self.eligible_people
    inactive_or_unencountered_people
      .where.not(id: recently_reminded_person_ids)
      .order(Person.arel_table[:last_encountered_at].asc.nulls_first)
      .order(:id)
  end

  def self.inactive_or_unencountered_people
    Person.where(last_encountered_at: ..INACTIVITY_PERIOD.ago)
      .or(Person.where(last_encountered_at: nil))
  end

  def self.recently_reminded_person_ids
    where(remind_on: RECENT_REMINDER_EXCLUSION_PERIOD.ago.to_date..Date.current).select(:person_id)
  end
  private_class_method :inactive_or_unencountered_people, :recently_reminded_person_ids
end
