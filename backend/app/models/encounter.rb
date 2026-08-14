class Encounter < ApplicationRecord
  belongs_to :person

  has_many :encounter_tags, dependent: :destroy
  has_many :tags, through: :encounter_tags

  validates :met_at, presence: true

  after_create :recalculate_person_last_encountered_at
  after_destroy :recalculate_person_last_encountered_at

  private

  def recalculate_person_last_encountered_at
    # 同じ人物への並行記録で古いMAX値が後勝ちしないよう、再計算を行ロックで直列化する。
    locked_person = Person.lock("FOR NO KEY UPDATE").find(person_id)
    locked_person.update_columns(last_encountered_at: locked_person.encounters.maximum(:met_at))
    self.person = locked_person unless destroyed?
  end
end
