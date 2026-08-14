module Api
  module V1
    class PeopleController < ApplicationController
      def index
        people = Person.with_encounters_count
          .order(Person.arel_table[:last_encountered_at].desc.nulls_last)
          .order(id: :desc)

        render json: { people: people.map { |person| person_summary(person) } }
      end

      def show
        person = Person.find(params[:id])
        encounters = person.encounters.includes(:tags).order(met_at: :desc, id: :desc)

        render json: { person: person_detail(person, encounters) }
      end

      def update
        person = Person.find(params[:id])
        form = People::UpdateForm.new(person: person, parameters: require_object_param(:person))

        if form.save
          render json: { person: person_attributes(person) }
        else
          render_validation_errors(form.errors.to_hash)
        end
      end

      private

      def person_summary(person)
        # with_encounters_countで付与される仮想属性を一覧レスポンスに含める。
        person_attributes(person).merge(encounters_count: person.encounters_count.to_i)
      end

      def person_detail(person, encounters)
        person_attributes(person).merge(
          encounters: encounters.map { |encounter| EncounterPresenter.serialize(encounter) }
        )
      end

      def person_attributes(person)
        {
          id: person.id,
          name: person.name,
          note: person.note,
          last_encountered_at: TimestampPresenter.serialize(person.last_encountered_at)
        }
      end
    end
  end
end
