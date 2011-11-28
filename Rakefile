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

  dictionary_files = Dir["#{File.dirname(__FILE__)}/dictionaries/*.txt"]

  dictionary_files.each do |dictionary_file|
    ActiveRecord::Base.transaction do
      dic_lines = File.read(dictionary_file).split(/\r?\n/)
      dictionary = Dictionary.create!(name: dic_lines.shift, official: true)
      dic_lines.each do |line|
        dictionary.themes.create! text: line.chomp
      end
    end
  end
end

desc 'Set up database'
task 'db:setup' => %w(db:migrate db:seed)

desc 'Compile coffeescripts into javascript files'
task 'coffee' do
  require 'coffee_script'
  coffees = Dir["#{File.dirname(__FILE__)}/views/*.coffee"]
  dir = "#{File.dirname(__FILE__)}/public/js/"
  javascripts = coffees.map do |coffee|
    File.basename(coffee).sub(/\.coffee$/,".js").prepend(dir)
  end

  Dir.mkdir(dir) unless File.exists?(dir)
  coffees.zip(javascripts).each do |coffee,javascript|
    puts "#{coffee.sub(File.dirname(__FILE__)+"/","")} -> #{javascript.sub(File.dirname(__FILE__)+"/","")}"
    File.write javascript, CoffeeScript.compile(open(coffee))
  end
end
