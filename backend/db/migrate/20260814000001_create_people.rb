class CreatePeople < ActiveRecord::Migration[8.1]
  def change
    create_table :people do |t|
      t.string :name, null: false
      t.text :note, null: false, default: ""
      t.datetime :last_encountered_at

      t.timestamps
    end

    add_index :people, :last_encountered_at
  end
end
