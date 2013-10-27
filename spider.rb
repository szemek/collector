require 'httparty'
require 'nokogiri'
require 'sequel'
require 'set'
require 'uri'
require 'colored'

class Spider
  attr_accessor :resources, :visited_links, :unvisited_links, :bad_uris

  def initialize(start_page, host)
    @start_page = start_page
    @host = host

    @visited_links = Set.new
    @unvisited_links = Set.new
    @bad_uris = Set.new
    @resources = Set.new
  end

  def run
    visit!(@start_page)

    until @unvisited_links.empty?
      Set.new(@unvisited_links).each{|link| visit!(link)}
    end
  end

  def visit!(page)
    @visited_links.add(page)

    response = HTTParty.get(page)
    doc = Nokogiri::HTML(response.body)

    links = extract_resources(doc, 'a[href]', 'href')

    scripts = extract_resources(doc, 'script[src]', 'src')
    stylesheets = extract_resources(doc, 'link[rel=stylesheet]', 'href')
    images = extract_resources(doc, 'img[src]', 'src')

    @resources.merge(scripts + stylesheets + images)

    @unvisited_links.merge(links)
    @unvisited_links.subtract(@visited_links)

    puts "visited: #{@visited_links.count}".green
    puts "unvisited: #{@unvisited_links.count}".green
  end

  def extract_resources(document, selector, attribute)
    document.css(selector).map{|e| e[attribute]}.select{|resource| filter_by_host(resource)}
  end

  def filter_by_host(resource)
    begin
      uri = URI(resource)
    rescue URI::InvalidURIError => error
      @bad_uris.add(resource)
      puts "#{error.message}".yellow
      return false
    end

    uri.host == @host
  end

  def persist!
    `rm -f #{@host}.sqlite3`
    @db = Sequel.sqlite("#{@host}.sqlite3")

    persist_collection(@resources, :resources)
    persist_collection(@visited_links, :visited_links)
    persist_collection(@bad_uris, :bad_uris)
  end

  def persist_collection(collection, table_name)
    @db.create_table(table_name) do
      primary_key :id
      String :url, :unique => true, :null => false
    end

    dataset = @db[table_name]
    collection.each{|e| dataset.insert(:url => e)}
  end
end
