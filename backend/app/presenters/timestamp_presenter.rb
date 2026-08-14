class TimestampPresenter
  def self.serialize(datetime)
    datetime&.utc&.iso8601
  end
end
