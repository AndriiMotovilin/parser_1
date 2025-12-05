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
require_relative "cart"
require_relative "configurator"

class BooksScraper
  class << self
    def run(config_hash, configurator = nil)
      web_config     = config_hash["web_scraping"] || {}
      output_config  = config_hash["output"] || {}

      base_url           = web_config["start_page"] || "https://books.toscrape.com/"
      csv_path           = output_config["csv_path"] || "output/data.csv"
      json_path          = output_config["json_path"] || "output/data.json"
      yaml_products_path = output_config["yaml_products_path"] || "config/yaml_config/products/books_from_site.yaml"
      yaml_items_dir     = "config/yaml_config/products/from_cart"

      configurator ||= MyApplicationMotovilin::Configurator.new(
        run_website_parser: 1,
        run_save_to_csv: 1,
        run_save_to_json: 1,
        run_save_to_yaml: 1,
        run_save_to_sqlite: 0,
        run_save_to_mongodb: 0
      )

      MyApplicationMotovilin::LoggerManager.log_processed_file(
        "BooksScraper started with BASE_URL=#{base_url}, config=#{configurator.config.inspect}"
      )

      unless configurator.enabled?(:run_website_parser)
        puts "Website parser is disabled by configurator."
        MyApplicationMotovilin::LoggerManager.log_processed_file(
          "Website parser disabled by configurator"
        )
        return
      end

      doc   = fetch_page(base_url)
      items = parse_items_from_doc(doc, web_config)
      cart = MyApplicationMotovilin::Cart.new(items)

      if configurator.enabled?(:run_save_to_csv)
        cart.save_to_csv(csv_path)
      else
        MyApplicationMotovilin::LoggerManager.log_processed_file("Saving to CSV disabled by configurator")
      end

      if configurator.enabled?(:run_save_to_json)
        cart.save_to_json(json_path)
      else
        MyApplicationMotovilin::LoggerManager.log_processed_file("Saving to JSON disabled by configurator")
      end

      if configurator.enabled?(:run_save_to_yaml)
        cart.save_to_file("output/items.txt")
        cart.save_to_yml(yaml_items_dir)
        save_to_products_yaml(items, yaml_products_path)
      else
        MyApplicationMotovilin::LoggerManager.log_processed_file("Saving to YAML disabled by configurator")
      end

      if configurator.enabled?(:run_save_to_sqlite)
        save_to_sqlite(items, config_hash["database_config"] && config_hash["database_config"]["sqlite_database"])
      end

      if configurator.enabled?(:run_save_to_mongodb)
        save_to_mongodb(items, config_hash["database_config"] && config_hash["database_config"]["mongodb_database"])
      end

      MyApplicationMotovilin::LoggerManager.log_processed_file("BooksScraper finished. Items count: #{items.size}")

      puts "Items: #{items.size}"
      puts "CSV:   #{csv_path}   (#{configurator.enabled?(:run_save_to_csv)   ? 'ON' : 'OFF'})"
      puts "JSON:  #{json_path}  (#{configurator.enabled?(:run_save_to_json)  ? 'ON' : 'OFF'})"
      puts "YAML:  #{yaml_products_path} (#{configurator.enabled?(:run_save_to_yaml) ? 'ON' : 'OFF'})"
    rescue StandardError => e
      MyApplicationMotovilin::LoggerManager.log_error("BooksScraper error: #{e.class} - #{e.message}")
      puts "Error: #{e.message}"
    end

    private

    def fetch_page(url)
      response = HTTParty.get(url)
      raise "Request failed with code #{response.code}" unless response.code == 200
      Nokogiri::HTML(response.body)
    end

    def parse_items_from_doc(doc, web_config)
      name_selector        = web_config["product_name_selector"]        || "article.product_pod h3 a"
      price_selector       = web_config["product_price_selector"]       || "article.product_pod p.price_color"
      description_selector = web_config["product_description_selector"]
      image_selector       = web_config["product_image_selector"]       || "article.product_pod div.image_container img"
      start_page = web_config["start_page"] || "https://books.toscrape.com/"

      items = []
      doc.css("article.product_pod").each do |book_node|
        link_node = book_node.at_css(name_selector) || book_node.at_css("h3 a")
        title     = link_node["title"]
        relative_url = link_node["href"]
        url = URI.join(start_page, relative_url).to_s

        price_node  = book_node.at_css(price_selector) || book_node.at_css("p.price_color")
        price_text  = price_node&.text&.strip
        price_value = normalize_price(price_text)

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

        item = MyApplicationMotovilin::Item.new(
          name:        title,
          price:       price_value,
          description: description || "",
          category:    "Books",
          image_path:  image_url || url,
          rating:      rating,
          availability: availability,
          url:         url
        )

        items << item
      end
      items
    end

    def save_to_products_yaml(items, path)
      FileUtils.mkdir_p(File.dirname(path))
      yaml_data = {
        "categories" => [
          {
            "name" => "Books",
            "products" => items.map do |item|
              {
                "name"        => item.name,
                "price"       => item.price,
                "description" => item.description.to_s,
                "media"       => item.image_path.to_s
              }
            end
          }
        ]
      }
      File.write(path, yaml_data.to_yaml)
      MyApplicationMotovilin::LoggerManager.log_processed_file("Single products YAML saved to #{path}")
    end

    def normalize_price(price_str)
      return nil unless price_str
      cleaned = price_str.gsub(/[^\d\.]/, "")
      cleaned.empty? ? nil : cleaned.to_f
    end

    def save_to_sqlite(items, sqlite_config)
      db_file = sqlite_config && sqlite_config["db_file"]
      MyApplicationMotovilin::LoggerManager.log_processed_file(
        "save_to_sqlite stub called. Items: #{items.size}, db_file=#{db_file.inspect}"
      )
    end

    def save_to_mongodb(items, mongo_config)
      uri = mongo_config && mongo_config["uri"]
      MyApplicationMotovilin::LoggerManager.log_processed_file(
        "save_to_mongodb stub called. Items: #{items.size}, uri=#{uri.inspect}"
      )
    end
  end
end
