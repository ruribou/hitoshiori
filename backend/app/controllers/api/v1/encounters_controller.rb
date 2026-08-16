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

      def destroy
        encounter = Encounter.find(params[:id])
        person = encounter.person

        ActiveRecord::Base.transaction do
          person.lock!
          encounter.destroy!
          person.destroy! if remove_empty_person? && person.encounters.none?
        end

        head :no_content
      end

      private

      def encounter_params
        raw_parameters = require_object_param(:encounter)

        {
          person_id: raw_parameters[:person_id],
          person_name: raw_parameters[:person_name],
          met_at: raw_parameters[:met_at],
          topic: raw_parameters[:topic],
          memo: raw_parameters[:memo],
          tag_names: raw_parameters.key?(:tag_names) ? raw_parameters[:tag_names] : []
        }
      end

      def remove_empty_person?
        ActiveModel::Type::Boolean.new.cast(params[:remove_empty_person])
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
          encounter: EncounterPresenter.serialize(encounter, tags: tags).merge(
            person: PersonPresenter.serialize(person).slice(:id, :name, :last_encountered_at)
          )
        }
      end
    end
  end
end
