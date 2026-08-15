class ReminderPresenter
  def self.serialize(reminder, last_encounter:)
    person = reminder.person

    {
      id: reminder.id,
      remind_on: reminder.remind_on.iso8601,
      person: PersonPresenter.serialize(person).merge(
        last_encounter: last_encounter && EncounterPresenter.serialize(last_encounter).slice(:met_at, :topic, :tags)
      )
    }
  end
end
