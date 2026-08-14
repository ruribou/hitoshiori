module Api
  module V1
    class EncountersController < ApplicationController
      def create
        attributes = encounter_params
        return render_validation_errors(person_name: [ "を入力してください" ]) unless person_specified?(attributes)

        encounter, tags = ActiveRecord::Base.transaction do
          person = find_or_create_person(attributes)
          encounter = person.encounters.create!(encounter_attributes(attributes))
          tags = find_or_create_tags(attributes[:tag_names])
          encounter.tags.concat(tags)

          [ encounter, tags ]
        end

        render json: encounter_response(encounter, tags), status: :created
      end

      private

      def encounter_params
        params.require(:encounter).permit(:person_id, :person_name, :met_at, :topic, :memo, tag_names: [])
      end

      def person_specified?(attributes)
        attributes[:person_id].present? || attributes[:person_name].present?
      end

      def find_or_create_person(attributes)
        return Person.find(attributes[:person_id]) if attributes[:person_id].present?

        Person.create!(name: attributes[:person_name])
      end

      def encounter_attributes(attributes)
        {
          met_at: attributes.key?(:met_at) ? attributes[:met_at] : Time.current,
          topic: attributes[:topic],
          memo: attributes[:memo]
        }
      end

      def find_or_create_tags(tag_names)
        normalize_tag_names(tag_names).map do |name|
          Tag.find_or_create_by!(name: name)
        end
      end

      def normalize_tag_names(tag_names)
        Array(tag_names).filter_map { |name| name.to_s.strip.presence }.uniq
      end

      def encounter_response(encounter, tags)
        person = encounter.person.reload

        {
          encounter: {
            id: encounter.id,
            met_at: encounter.met_at.utc.iso8601,
            topic: encounter.topic,
            memo: encounter.memo,
            tags: tags.map { |tag| { id: tag.id, name: tag.name } },
            person: {
              id: person.id,
              name: person.name,
              last_encountered_at: person.last_encountered_at.utc.iso8601
            }
          }
        }
      end
    end
  end
end
