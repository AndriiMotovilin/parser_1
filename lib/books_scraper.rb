# lib/books_scraper.rb
# frozen_string_literal: true

require "httparty"
require "nokogiri"
require "csv"
require "json"
require "uri"
require "yaml"
require "fileutils"
require_relative "my_application_motovilin"

class BooksScraper
  class << self
    # run приймає хеш усіх конфігів
    def run(config_hash)
      web_config    = config_hash["web_scraping"] || {}
      output_config = config_hash["output"] || {}

      base_url          = web_config["start_page"] || "https://books.toscrape.com/"
      csv_path          = output_config["csv_path"] || "output/data.csv"
      json_path         = output_config["json_path"] || "output/data.json"
      yaml_products_path = output_config["yaml_products_path"] || "config/yaml_config/products/books_from_site.yaml"

      MyApplicationMotovilin::LoggerManager.log_processed_file(
        "BooksScraper started with BASE_URL=#{base_url}"
      )

      doc   = fetch_page(base_url)
      books = parse_books_from_doc(doc, web_config)

      save_to_csv(books, csv_path)
      save_to_json(books, json_path)
      save_to_products_yaml(books, yaml_products_path)

      MyApplicationMotovilin::LoggerManager.log_processed_file(
        "BooksScraper finished. Saved #{books.size} books."
      )

      puts "Saved #{books.size} books to:"
      puts "  - #{csv_path}"
      puts "  - #{json_path}"
      puts "  - #{yaml_products_path} (YAML у форматі categories/products)"
    rescue StandardError => e
      MyApplicationMotovilin::LoggerManager.log_error(
        "BooksScraper error: #{e.class} - #{e.message}"
      )
      puts "Error: #{e.message}"
    end

    private

    def fetch_page(url)
      response = HTTParty.get(url)
      raise "Request failed with code #{response.code}" unless response.code == 200

      Nokogiri::HTML(response.body)
    end

    def parse_books_from_doc(doc, web_config)
      name_selector        = web_config["product_name_selector"]        || "article.product_pod h3 a"
      price_selector       = web_config["product_price_selector"]       || "article.product_pod p.price_color"
      description_selector = web_config["product_description_selector"]
      image_selector       = web_config["product_image_selector"]       || "article.product_pod div.image_container img"

      start_page = web_config["start_page"] || "https://books.toscrape.com/"

      books = []

      doc.css("article.product_pod").each do |book_node|
        link_node = book_node.at_css(name_selector) || book_node.at_css("h3 a")
        title     = link_node["title"]
        relative_url = link_node["href"]
        url = URI.join(start_page, relative_url).to_s

        price_node = book_node.at_css(price_selector) || book_node.at_css("p.price_color")
        price      = price_node&.text&.strip

        availability = book_node.at_css("p.instock.availability")&.text&.strip

        description = nil
        if description_selector && !description_selector.empty?
          description_node = book_node.at_css(description_selector)
          description = description_node&.text&.strip
        end

        image_node = book_node.at_css(image_selector)
        image_url  = if image_node && image_node["src"]
                       URI.join(start_page, image_node["src"]).to_s
                     end

        rating_node  = book_node.at_css("p.star-rating")
        rating_class = rating_node["class"].split - ["star-rating"]
        rating       = rating_class.first

        books << {
          title:        title,
          price:        price,
          availability: availability,
          rating:       rating,
          url:          url,
          description:  description,
          image_url:    image_url
        }
      end

      books
    end

    def save_to_csv(books, path)
      headers = %w[title price availability rating url description image_url]

      CSV.open(path, "w", write_headers: true, headers: headers) do |csv|
        books.each do |book|
          csv << headers.map { |h| book[h.to_sym] }
        end
      end
    end

    def save_to_json(books, path)
      File.write(path, JSON.pretty_generate(books))
    end

    # ✅ ГОЛОВНЕ: збереження ВСІХ даних в одному YAML-файлі
    # у форматі як у прикладі з "Вітамінами":
    #
    # categories:
    #   - name: Books
    #     products:
    #       - name: ...
    #         price: ...
    #         description: ...
    #         media: ...
    #
    def save_to_products_yaml(books, path)
      FileUtils.mkdir_p(File.dirname(path))

      yaml_data = {
        "categories" => [
          {
            "name" => "Books",
            "products" => books.map do |book|
              {
                "name"        => book[:title],
                "price"       => normalize_price(book[:price]),
                "description" => book[:description] || "",
                # в media кладемо або картинку, або хоча б посилання на книгу
                "media"       => book[:image_url] || book[:url]
              }
            end
          }
        ]
      }

      File.write(path, yaml_data.to_yaml)
    end

    def normalize_price(price_str)
      return nil unless price_str

      # "£51.77" -> 51.77
      cleaned = price_str.gsub(/[^\d\.]/, "")
      cleaned.empty? ? nil : cleaned.to_f
    end
  end
end
