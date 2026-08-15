class Person < ApplicationRecord
  has_many :encounters
  has_many :reminders
  has_one :last_encounter, -> { order(met_at: :desc, id: :desc) }, class_name: "Encounter"

  scope :with_encounters_count, -> {
    left_joins(:encounters)
      .select("people.*, COUNT(encounters.id) AS encounters_count")
      .group("people.id")
  }

  validates :name, presence: true
end
