class CreateEncounterTags < ActiveRecord::Migration[8.1]
  def change
    create_table :encounter_tags do |t|
      t.references :encounter, null: false, foreign_key: true, index: false
      t.references :tag, null: false, foreign_key: true, index: false
    end

    add_index :encounter_tags, [ :encounter_id, :tag_id ], unique: true
  end
end
