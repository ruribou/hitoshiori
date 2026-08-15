class ReminderPresenter
  def self.serialize(reminder)
    person = reminder.person
    last_encounter = person.last_encounter

    {
      id: reminder.id,
      remind_on: reminder.remind_on.iso8601,
      person: {
        id: person.id,
        name: person.name,
        note: person.note,
        last_encountered_at: TimestampPresenter.serialize(person.last_encountered_at),
        last_encounter: last_encounter_attributes(last_encounter)
      }
    }
  end

  def self.last_encounter_attributes(encounter)
    return if encounter.nil?

    {
      met_at: TimestampPresenter.serialize(encounter.met_at),
      topic: encounter.topic,
      tags: TagPresenter.serialize_collection(encounter.tags)
    }
  end
  private_class_method :last_encounter_attributes
end
