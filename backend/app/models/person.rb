class Person < ApplicationRecord
  has_many :encounters

  scope :with_encounters_count, -> {
    left_joins(:encounters)
      .select("people.*, COUNT(encounters.id) AS encounters_count")
      .group("people.id")
  }

  validates :name, presence: true
end
