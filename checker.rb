require 'sequel'
require 'httparty'

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

    codes = collection.map{|record| HTTParty.head(record[:url]).code}
    unique_codes = codes.sort.uniq

    puts unique_codes.map{|code| {code => codes.count}}
  end
end
