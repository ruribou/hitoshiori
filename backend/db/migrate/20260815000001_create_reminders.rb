class CreateReminders < ActiveRecord::Migration[8.1]
  def change
    create_table :reminders do |t|
      t.references :person, null: false, foreign_key: true
      t.date :remind_on, null: false

      t.timestamps
    end

    add_index :reminders, :remind_on, unique: true
  end
end
