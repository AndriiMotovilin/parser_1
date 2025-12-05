# lib/configurator.rb
# frozen_string_literal: true

require_relative "my_application_motovilin"

module MyApplicationMotovilin
  class Configurator
    VALID_KEYS = %i[
      run_website_parser
      run_save_to_csv
      run_save_to_json
      run_save_to_yaml
      run_save_to_sqlite
      run_save_to_mongodb
    ].freeze

    attr_reader :config

    def initialize(initial_overrides = {})
      @config = {}
      VALID_KEYS.each { |key| @config[key] = 0 }
      configure(initial_overrides) if initial_overrides && !initial_overrides.empty?
      LoggerManager.log_processed_file("Configurator initialized with: #{@config.inspect}")
    rescue StandardError => e
      LoggerManager.log_error("Configurator initialization error: #{e.class} - #{e.message}")
      raise
    end

    def configure(overrides = {})
      overrides.each do |key, value|
      sym_key = key.to_sym
        if @config.key?(sym_key)
          @config[sym_key] = value
        else
          warn "Warning: invalid config key: #{key}"
          LoggerManager.log_error("Configurator invalid key: #{key}") rescue nil
        end
      end
      @config
    end

    def [](key)
      @config[key.to_sym]
    end

    def enabled?(key)
      value = @config[key.to_sym]
      return false if value.nil?
      value.respond_to?(:to_i) ? value.to_i != 0 : !!value
    end

    def self.available_methods
      VALID_KEYS
    end
  end
end
