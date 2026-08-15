class PersonPresenter
  def self.serialize(person)
    {
      id: person.id,
      name: person.name,
      note: person.note,
      last_encountered_at: TimestampPresenter.serialize(person.last_encountered_at)
    }
  end
end
