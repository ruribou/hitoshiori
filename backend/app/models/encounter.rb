class Encounter < ApplicationRecord
  belongs_to :person

  has_many :encounter_tags, dependent: :destroy
  has_many :tags, through: :encounter_tags

  validates :met_at, presence: true

  after_create :recalculate_person_last_encountered_at
  after_destroy :recalculate_person_last_encountered_at

  private

  def recalculate_person_last_encountered_at
    person.update_columns(last_encountered_at: person.encounters.maximum(:met_at))
  end
end
