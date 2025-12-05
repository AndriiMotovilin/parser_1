# lib/books_scraper.rb
# frozen_string_literal: true

require "httparty"
require "nokogiri"
require "csv"
require "yaml"
require "json"
require "uri"

class BooksScraper
  CONFIG    = YAML.load_file("config/application.yml")
  BASE_URL  = CONFIG.dig("source", "base_url") || "https://books.toscrape.com/"
  CSV_PATH  = CONFIG.dig("output", "csv_path") || "output/data.csv"
  JSON_PATH = CONFIG.dig("output", "json_path") || "output/data.json"
  LOG_PATH  = "logs/application.log"

  class << self
    def run
      log "BooksScraper started with BASE_URL=#{BASE_URL}"

      doc   = fetch_page(BASE_URL)
      books = parse_books_from_doc(doc)

      save_to_csv(books, CSV_PATH)
      save_to_json(books, JSON_PATH)

      log "BooksScraper finished. Saved #{books.size} books."
      puts "Saved #{books.size} books to #{CSV_PATH} and #{JSON_PATH}"
    rescue StandardError => e
      log "ERROR: #{e.class} - #{e.message}"
      puts "Error: #{e.message}"
    end

    private

    def fetch_page(url)
      log "Fetching URL: #{url}"
      response = HTTParty.get(url)
      raise "Request failed with code #{response.code}" unless response.code == 200

      Nokogiri::HTML(response.body)
    end

    # Парсимо одну сторінку (головну) Books to Scrape
    def parse_books_from_doc(doc)
      books = []

      doc.css("article.product_pod").each do |book_node|
        link_node    = book_node.at_css("h3 a")
        title        = link_node["title"]
        relative_url = link_node["href"]
        url          = URI.join(BASE_URL, relative_url).to_s

        price        = book_node.at_css("p.price_color")&.text&.strip
        availability = book_node.at_css("p.instock.availability")&.text&.strip
        rating_node  = book_node.at_css("p.star-rating")
        rating_class = rating_node["class"].split - ["star-rating"]
        rating       = rating_class.first # "One", "Two", "Three"...

        books << {
          title:        title,
          price:        price,
          availability: availability,
          rating:       rating,
          url:          url
        }
      end

      log "Parsed #{books.size} books from page."
      books
    end

    def save_to_csv(books, path)
      CSV.open(path, "w", write_headers: true, headers: %w[title price availability rating url]) do |csv|
        books.each do |book|
          csv << [
            book[:title],
            book[:price],
            book[:availability],
            book[:rating],
            book[:url]
          ]
        end
      end
      log "Saved CSV to #{path}"
    end

    def save_to_json(books, path)
      File.write(path, JSON.pretty_generate(books))
      log "Saved JSON to #{path}"
    end

    def log(message)
      File.open(LOG_PATH, "a") do |file|
        file.puts("[#{Time.now}] #{message}")
      end
    end
  end
end
