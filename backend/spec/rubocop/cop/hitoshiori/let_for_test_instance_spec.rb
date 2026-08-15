require "rails_helper"
require "rubocop"
require Rails.root.join("rubocop/cop/hitoshiori/let_for_test_instance")

RSpec.describe RuboCop::Cop::Hitoshiori::LetForTestInstance do
  let(:cop) { described_class.new(RuboCop::Config.new) }
  let(:commissioner) { RuboCop::Cop::Commissioner.new([ cop ], [], raise_error: true) }
  let(:processed_source) { RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f) }
  let(:offenses) { commissioner.investigate(processed_source).offenses }

  context "example内でインスタンスを直接生成する場合" do
    let(:source) do
      <<~RUBY
        RSpec.describe Person do
          it "生成する" do
            person = Person.create!
            encounter = person.encounters.build
            described_class.new
          end
        end
      RUBY
    end

    it "違反として報告する" do
      expect(offenses.map(&:line)).to eq([ 3, 4, 5 ])
    end
  end

  context "インスタンスをletで定義する場合" do
    let(:source) do
      <<~RUBY
        RSpec.describe Person do
          let(:person) { Person.create! }
          let!(:encounter) { person.encounters.build }
          let(:invalid_person) { described_class.new }

          it "利用する" do
            person
            encounter
            invalid_person
          end
        end
      RUBY
    end

    it "違反にしない" do
      expect(offenses).to be_empty
    end
  end

  context "example内でインスタンスを生成しない場合" do
    let(:source) do
      <<~RUBY
        RSpec.describe "People API" do
          it "一覧を取得する" do
            get "/api/v1/people"
          end
        end
      RUBY
    end

    it "違反にしない" do
      expect(offenses).to be_empty
    end
  end
end
