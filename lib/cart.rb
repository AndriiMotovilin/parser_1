# lib/cart.rb
# frozen_string_literal: true

require "json"
require "csv"
require "yaml"
require "fileutils"
require_relative "item_container"

module MyApplicationMotovilin
  class Cart
    include ItemContainer
    include Enumerable

    def initialize(items = [])
      @items = []
      items&.each { |item| add_item(item) }
      LoggerManager.log_processed_file("Cart initialized with #{@items.size} items")
    end

    def each(&block)
      @items.each(&block)
    end

    def save_to_file(path = "output/items.txt")
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, "w") do |f|
        @items.each do |item|
          f.puts(item.info)
        end
      end
      LoggerManager.log_processed_file("Cart saved to text file: #{path}")
      path
    end

    def save_to_json(path = "output/items_from_cart.json")
      FileUtils.mkdir_p(File.dirname(path))
      data = @items.map(&:to_h)
      File.write(path, JSON.pretty_generate(data))
      LoggerManager.log_processed_file("Cart saved to JSON: #{path}")
      path
    end

    def save_to_csv(path = "output/items_from_cart.csv")
      FileUtils.mkdir_p(File.dirname(path))
      headers = %w[name price availability rating url description image_path category]
      CSV.open(path, "w", write_headers: true, headers: headers) do |csv|
        @items.each do |item|
          h = item.to_h
          csv << headers.map { |key| h[key.to_sym] }
        end
      end
      LoggerManager.log_processed_file("Cart saved to CSV: #{path}")
      path
    end

    def save_to_yml(dir = "config/yaml_config/products/from_cart")
      FileUtils.mkdir_p(dir)
      @items.each_with_index do |item, index|
        file_path = File.join(dir, "item_#{index + 1}.yml")
        File.write(file_path, item.to_h.to_yaml)
      end
      LoggerManager.log_processed_file(
        "Cart saved to YAML directory (one file per item): #{dir}"
      )
      dir
    end

    def expensive_items(min_price)
      select { |item| item.price && item.price >= min_price }
    end

    def find_by_name(name)
      find { |item| item.name.to_s.strip == name.to_s.strip }
    end

    def total_price
      reduce(0.0) { |sum, item| sum + (item.price || 0.0) }
    end

    def all_in_stock?
      all? { |item| item.availability.to_s.downcase.include?("in stock") }
    end

    def any_out_of_stock?
      any? { |item| item.availability.to_s.downcase.include?("out of stock") }
    end

    def unique_categories
      map(&:category).compact.uniq
    end

    def sorted_by_price
      sort
    end
  end
end
