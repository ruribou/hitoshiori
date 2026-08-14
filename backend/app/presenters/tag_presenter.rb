class TagPresenter
  def self.serialize(tag)
    { id: tag.id, name: tag.name }
  end

  def self.serialize_collection(tags)
    tags.map { |tag| serialize(tag) }
  end
end
