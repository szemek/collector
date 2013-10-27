require 'sequel'
require 'httparty'
require 'colored'

class Checker
  def initialize(host)
    @host = host
  end

  def run
    @db = Sequel.sqlite("#{@host}.sqlite3")
    check_collection(:resources)
    check_collection(:visited_links)
    check_collection(:bad_uris)
  end

  def check_collection(table_name)
    collection = @db[table_name].all

    collection.each do |record|
      response = HTTParty.head(record[:url])
      code = response.code

      if [200].include?(code)
        puts "#{code}: #{record[:url]}".green
      else
        puts "#{code}: #{record[:url]}".red
      end
    end
  end
end
