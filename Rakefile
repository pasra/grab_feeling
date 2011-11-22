require_relative './lib/grab_feeling.rb'

desc 'Migrate the database'
task 'db:migrate' do
  require_relative './db/migrate'
  puts 'Upgrading Database...'
  TheMigration.up
end

desc 'Execute seed script'
task 'db:seed' do
  puts 'Initializing Database...'
end

desc 'Set up database'
task 'db:setup' => %w(db:migrate db:seed)
