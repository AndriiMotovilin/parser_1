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

class BooksScraper
  class << self
    def run(config_hash)
      web_config     = config_hash["web_scraping"] || {}
      output_config  = config_hash["output"] || {}

      base_url           = web_config["start_page"] || "https://books.toscrape.com/"
      csv_path           = output_config["csv_path"] || "output/data.csv"
      json_path          = output_config["json_path"] || "output/data.json"
      yaml_products_path = output_config["yaml_products_path"] || "config/yaml_config/products/books_from_site.yaml"

      yaml_items_dir = "config/yaml_config/products/from_cart"

      MyApplicationMotovilin::LoggerManager.log_processed_file(
        "BooksScraper started with BASE_URL=#{base_url}"
      )

      doc   = fetch_page(base_url)
      items = parse_items_from_doc(doc, web_config)

      cart = MyApplicationMotovilin::Cart.new(items)

      cart.save_to_csv(csv_path)
      cart.save_to_json(json_path)
      cart.save_to_file("output/items.txt")
      cart.save_to_yml(yaml_items_dir)


      save_to_products_yaml(items, yaml_products_path)

      MyApplicationMotovilin::LoggerManager.log_processed_file(
        "BooksScraper finished. Saved #{items.size} items."
      )

      puts "Saved #{items.size} items to:"
      puts "  - #{csv_path} (CSV via Cart)"
      puts "  - #{json_path} (JSON via Cart)"
      puts "  - output/items.txt (text via Cart)"
      puts "  - #{yaml_items_dir} (many YAML files, one per item via Cart)"
      puts "  - #{yaml_products_path} (single YAML file, categories/products format)"
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
      MyApplicationMotovilin::LoggerManager.log_processed_file(
        "Single products YAML saved to #{path}"
      )
    end

    def normalize_price(price_str)
      return nil unless price_str

      cleaned = price_str.gsub(/[^\d\.]/, "")
      cleaned.empty? ? nil : cleaned.to_f
    end
  end
end
