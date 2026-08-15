class DailyReminderJob < ApplicationJob
  def perform
    Reminder.create_for_today!
  rescue ActiveRecord::RecordNotUnique
    # reminders.remind_on の一意制約で多重実行時も1日1件に保たれる。
  end
end
