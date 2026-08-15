class DailyReminderJob < ApplicationJob
  def perform
    create_reminder_for_today
  end

  private

  def create_reminder_for_today
    Reminder.create_for_today!
  rescue ActiveRecord::RecordNotUnique
    # reminders.remind_on の一意制約で多重実行時も1日1件に保たれる。
    Rails.logger.info("日次想起は当日分が既に作成されているためスキップしました")
  end
end
