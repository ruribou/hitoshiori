module Encounters
  class CreateForm
    include ActiveModel::Model

    attr_accessor :person_id, :person_name, :met_at, :topic, :memo, :tag_names

    validates :person_name, presence: true, if: -> { person_id.blank? }
    validate :met_at_must_be_iso8601
    validate :tag_names_must_be_string_array

    attr_reader :resolved_met_at

    def normalized_tag_names
      tag_names.filter_map { |name| name.strip.presence }.uniq
    end

    private

    def met_at_must_be_iso8601
      @resolved_met_at = if met_at.blank?
        Time.current
      else
        raise ArgumentError unless met_at.to_s.match?(/(?:Z|[+-]\d{2}:\d{2})\z/)

        Time.iso8601(met_at.to_s).in_time_zone
      end
    rescue ArgumentError
      errors.add(:met_at, :invalid)
    end

    def tag_names_must_be_string_array
      return if tag_names.is_a?(Array) && tag_names.all? { |name| name.is_a?(String) }

      errors.add(:tag_names, :invalid)
    end
  end
end
