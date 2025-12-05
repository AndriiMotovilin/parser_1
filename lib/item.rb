# lib/item.rb
# frozen_string_literal: true

require "faker"
require_relative "my_application_motovilin"

module MyApplicationMotovilin
  class Item
    include Comparable

    # Не обов'язково, але зручно мати список атрибутів
    ATTRIBUTES = %i[
      name
      price
      description
      category
      image_path
      rating
      availability
      url
    ].freeze

    attr_accessor(*ATTRIBUTES)

    def initialize(params = {})
      defaults = {
        name: "Unknown item",
        price: 0.0,
        description: "",
        category: "Uncategorized",
        image_path: "",
        rating: nil,
        availability: nil,
        url: nil
      }

      data = defaults.merge(params.transform_keys(&:to_sym))

      ATTRIBUTES.each do |attr|
        send("#{attr}=", data[attr])
      end

      # Дозволяємо додаткову кастомізацію через блок:
      #
      # MyApplicationMotovilin::Item.new(name: "X") do |i|
      #   i.description = "..."
      # end
      if block_given?
        yield self
      end

      LoggerManager.log_processed_file("Item initialized: #{to_s}")
    rescue StandardError => e
      LoggerManager.log_error("Error during Item initialization: #{e.class} - #{e.message}")
      raise
    end

    # Для Comparable – порівнюємо за price
    def <=>(other)
      return nil unless other.is_a?(Item)

      (price || 0.0) <=> (other.price || 0.0)
    end

    # Динамічне формування хеша з атрибутів
    def to_h
      instance_variables.each_with_object({}) do |var, hash|
        key = var.to_s.delete("@").to_sym
        hash[key] = instance_variable_get(var)
      end
    end

    # Рядкове представлення (to_s)
    def to_s
      pairs = to_h.map { |k, v| "#{k}=#{v.inspect}" }
      "#<MyApplicationMotovilin::Item #{pairs.join(', ')}>"
    rescue StandardError => e
      LoggerManager.log_error("Error in Item#to_s: #{e.class} - #{e.message}")
      "#<MyApplicationMotovilin::Item ERROR>"
    end

    # Зручний варіант to_s (псевдонім info)
    alias_method :info, :to_s

    # Красивий inspect
    def inspect
      "#<MyApplicationMotovilin::Item name=#{name.inspect}, price=#{price.inspect}, category=#{category.inspect}>"
    end

    # Оновлення через блок:
    #
    # item.update do |i|
    #   i.name = "New name"
    #   i.price = 100
    # end
    def update
      return unless block_given?

      yield self
      LoggerManager.log_processed_file("Item updated: #{to_s}")
    rescue StandardError => e
      LoggerManager.log_error("Error in Item#update: #{e.class} - #{e.message}")
      raise
    end

    # Фейковий товар з Faker
    def self.generate_fake
      item = new(
        name: Faker::Book.title,
        price: rand(5.0..100.0).round(2),
        description: Faker::Lorem.sentence,
        category: Faker::Book.genre,
        image_path: "products/books/#{Faker::Internet.slug}.jpeg",
        rating: %w[One Two Three Four Five].sample,
        availability: %w[In\ stock Out\ of\ stock].sample,
        url: Faker::Internet.url
      )

      LoggerManager.log_processed_file("Fake Item generated: #{item.name}")
      item
    rescue StandardError => e
      LoggerManager.log_error("Error in Item.generate_fake: #{e.class} - #{e.message}")
      nil
    end
  end
end
