class Person < ApplicationRecord
  has_many :encounters

  validates :name, presence: true
end
