module Api
  module V1
    class PeopleController < ApplicationController
      def index
        people = Person
          .left_joins(:encounters)
          .select("people.*, COUNT(encounters.id) AS encounters_count")
          .group("people.id")
          .order(Person.arel_table[:last_encountered_at].desc.nulls_last)

        render json: { people: people.map { |person| person_summary(person) } }
      end

      def show
        person = Person.find(params[:id])
        encounters = person.encounters.includes(:tags).order(met_at: :desc)

        render json: { person: person_detail(person, encounters) }
      end

      def update
        person = Person.find(params[:id])

        if person.update(person_params)
          render json: { person: person_attributes(person) }
        else
          render_validation_errors(person.errors.to_hash)
        end
      end

      private

      def person_params
        raw_parameters = params.require(:person)
        raise ActionController::ParameterMissing.new(:person) unless raw_parameters.is_a?(ActionController::Parameters)

        raw_parameters.permit(:name, :note)
      end

      def person_summary(person)
        person_attributes(person).merge(encounters_count: person.encounters_count.to_i)
      end

      def person_detail(person, encounters)
        person_attributes(person).merge(
          encounters: encounters.map { |encounter| encounter_attributes(encounter) }
        )
      end

      def person_attributes(person)
        {
          id: person.id,
          name: person.name,
          note: person.note,
          last_encountered_at: iso8601(person.last_encountered_at)
        }
      end

      def encounter_attributes(encounter)
        {
          id: encounter.id,
          met_at: encounter.met_at.utc.iso8601,
          topic: encounter.topic,
          memo: encounter.memo,
          tags: encounter.tags.map { |tag| { id: tag.id, name: tag.name } }
        }
      end

      def iso8601(datetime)
        datetime&.utc&.iso8601
      end
    end
  end
end
