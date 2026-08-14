seeded_at = Time.zone.now.change(usec: 0)

tags_by_name = [ "ハッカソン", "STECH", "NxTEND", "IDEACTIVE" ].index_with do |name|
  Tag.find_or_create_by!(name: name)
end

people = [
  {
    name: "あおいさん",
    note: "STECHで知り合った",
    encounters: [
      { days_ago: 3, topic: "次の勉強会", memo: "Swiftの話をした", tags: [ "STECH" ] },
      { days_ago: 14, topic: "近況共有", memo: "開発中のアプリを見せてもらった", tags: [ "STECH" ] }
    ]
  },
  {
    name: "はるかさん",
    note: "ハッカソンで同じチームだった",
    encounters: [
      { days_ago: 1, topic: "企画相談", memo: "MVPの方向性を相談した", tags: [ "ハッカソン" ] }
    ]
  },
  {
    name: "れんさん",
    note: "NxTENDOの交流会で会った",
    encounters: [
      { days_ago: 40, topic: "ゲーム制作", memo: "個人制作について聞いた", tags: [ "NxTEND" ] }
    ]
  },
  {
    name: "そらさん",
    note: "IDEACTIVEの発表者",
    encounters: [
      { days_ago: 60, topic: "発表の感想", memo: "プロトタイプについて話した", tags: [ "IDEACTIVE" ] },
      { days_ago: 90, topic: "初顔合わせ", memo: "交流会で自己紹介した", tags: [ "IDEACTIVE" ] }
    ]
  },
  {
    name: "ゆきさん",
    note: "複数のイベントでよく会う",
    encounters: [
      { days_ago: 5, topic: "次のハッカソン", memo: "参加予定を確認した", tags: [ "ハッカソン", "STECH" ] },
      { days_ago: 12, topic: "技術選定", memo: "バックエンド構成について話した", tags: [ "STECH" ] },
      { days_ago: 20, topic: "アイデア交換", memo: "新しい企画を聞いた", tags: [ "IDEACTIVE" ] }
    ]
  }
]

people.each do |person_attributes|
  person = Person.find_or_initialize_by(name: person_attributes.fetch(:name))
  person.note = person_attributes.fetch(:note)
  person.save!

  person_attributes.fetch(:encounters).each do |encounter_attributes|
    encounter = Encounter.find_or_initialize_by(
      person: person,
      topic: encounter_attributes.fetch(:topic)
    )
    encounter.met_at = encounter_attributes.fetch(:days_ago).days.ago(seeded_at)
    encounter.memo = encounter_attributes.fetch(:memo)
    encounter.save!
    encounter.tags = encounter_attributes.fetch(:tags).map { |name| tags_by_name.fetch(name) }
  end

  person.update_columns(last_encountered_at: person.encounters.maximum(:met_at))
end
