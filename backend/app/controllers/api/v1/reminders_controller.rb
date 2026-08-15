module Api
  module V1
    class RemindersController < ApplicationController
      def today
        reminder = Reminder.includes(person: { last_encounter: :tags }).find_by(remind_on: Date.current)

        render json: { reminder: reminder && ReminderPresenter.serialize(reminder) }
      end
    end
  end
end
