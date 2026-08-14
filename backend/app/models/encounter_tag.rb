class EncounterTag < ApplicationRecord
  belongs_to :encounter
  belongs_to :tag
end
