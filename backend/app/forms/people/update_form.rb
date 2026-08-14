module People
  class UpdateForm
    include ActiveModel::Model

    UPDATABLE_ATTRIBUTES = [ :name, :note ].freeze

    attr_reader :person

    validate :attribute_values_must_be_strings

    def initialize(person:, parameters:)
      @person = person
      @attributes = UPDATABLE_ATTRIBUTES.each_with_object({}) do |attribute, result|
        result[attribute] = parameters[attribute] if parameters.key?(attribute)
      end
      @attributes[:note] = "" if @attributes.key?(:note) && @attributes[:note].nil?
    end

    def save
      return false unless valid?
      return true if person.update(attributes)

      errors.merge!(person.errors)
      false
    end

    def read_attribute_for_validation(attribute)
      attributes[attribute]
    end

    private

    attr_reader :attributes

    def attribute_values_must_be_strings
      attributes.each do |attribute, value|
        errors.add(attribute, :invalid) unless value.is_a?(String)
      end
    end
  end
end
