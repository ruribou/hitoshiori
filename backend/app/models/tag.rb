class Tag < ApplicationRecord
  has_many :encounter_tags, dependent: :destroy
  has_many :encounters, through: :encounter_tags

  validates :name, presence: true, uniqueness: true
end
