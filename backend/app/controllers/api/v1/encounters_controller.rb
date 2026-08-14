module Api
  module V1
    class EncountersController < ApplicationController
      def create
        form = Encounters::CreateForm.new(encounter_params)
        return render_validation_errors(form.errors.to_hash) unless form.valid?

        encounter, tags = ActiveRecord::Base.transaction do
          person = find_or_create_person(form)
          encounter = person.encounters.create!(
            met_at: form.resolved_met_at,
            topic: form.topic,
            memo: form.memo
          )
          tags = find_or_create_tags(form.normalized_tag_names)
          create_encounter_tags(encounter, tags)

          [ encounter, tags ]
        end

        render json: encounter_response(encounter, tags), status: :created
      end

      private

      def encounter_params
        raw_parameters = params.require(:encounter)
        raise ActionController::ParameterMissing.new(:encounter) unless raw_parameters.is_a?(ActionController::Parameters)

        {
          person_id: raw_parameters[:person_id],
          person_name: raw_parameters[:person_name],
          met_at: raw_parameters[:met_at],
          topic: raw_parameters[:topic],
          memo: raw_parameters[:memo],
          tag_names: raw_parameters.key?(:tag_names) ? raw_parameters[:tag_names] : []
        }
      end

      def find_or_create_person(form)
        return Person.find(form.person_id) if form.person_id.present?

        Person.create!(name: form.person_name)
      end

      def find_or_create_tags(names)
        return [] if names.empty?

        Tag.insert_all(names.map { |name| { name: name } }, unique_by: :index_tags_on_name)
        tags_by_name = Tag.where(name: names).index_by(&:name)
        names.map { |name| tags_by_name.fetch(name) }
      end

      def create_encounter_tags(encounter, tags)
        return if tags.empty?

        rows = tags.map { |tag| { encounter_id: encounter.id, tag_id: tag.id } }
        EncounterTag.insert_all(rows, unique_by: :index_encounter_tags_on_encounter_id_and_tag_id)
      end

      def encounter_response(encounter, tags)
        person = encounter.person

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
