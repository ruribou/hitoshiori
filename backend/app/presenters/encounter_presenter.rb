class EncounterPresenter
  def self.serialize(encounter, tags: encounter.tags)
    {
      id: encounter.id,
      met_at: TimestampPresenter.serialize(encounter.met_at),
      topic: encounter.topic,
      memo: encounter.memo,
      tags: TagPresenter.serialize_collection(tags)
    }
  end
end
