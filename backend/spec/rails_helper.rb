abort("本番環境ではspecを実行できません") if ENV["RAILS_ENV"] == "production"
ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"
require "rspec/rails"

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.before(:suite) do
    # db:prepare が新規test DBへseedを投入しても、exampleは常に空の状態から始める。
    ActiveRecord::Base.connection.execute <<~SQL
      TRUNCATE TABLE reminders, encounter_tags, encounters, tags, people RESTART IDENTITY CASCADE
    SQL
  end
end
