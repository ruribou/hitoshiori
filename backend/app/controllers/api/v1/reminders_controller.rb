module Api
  module V1
    class RemindersController < ApplicationController
      def today
        reminder = Reminder.includes(:person).find_by(remind_on: Date.current)

        render json: {
          reminder: reminder && ReminderPresenter.serialize(reminder, last_encounter: latest_encounter_for(reminder))
        }
      end

      private

      def latest_encounter_for(reminder)
        reminder.person.encounters.includes(:tags).order(met_at: :desc, id: :desc).first
      end
    end
  end
end
