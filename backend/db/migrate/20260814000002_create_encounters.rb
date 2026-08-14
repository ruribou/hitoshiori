class CreateEncounters < ActiveRecord::Migration[8.1]
  def change
    create_table :encounters do |t|
      t.references :person, null: false, foreign_key: true, index: false
      t.datetime :met_at, null: false
      t.string :topic
      t.text :memo

      t.timestamps
    end

    add_index :encounters, [ :person_id, :met_at ]
  end
end
