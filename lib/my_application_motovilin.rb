# lib/my_application_motovilin.rb
# frozen_string_literal: true

require "erb"
require "yaml"
require "json"
require "logger"
require "fileutils"

module MyApplicationMotovilin
  # Клас для завантаження конфігів YAML і автопідключення бібліотек
  class AppConfigLoader
    class << self
      attr_reader :config_data, :loaded_libs

      # Автоматичне підключення системних та локальних бібліотек
      def load_libs
        system_libs = %w[date json yaml logger fileutils erb]
        system_libs.each { |lib| require lib }

        @loaded_libs ||= []
        Dir.glob("lib/**/*.rb").each do |file|
          abs = File.expand_path(file)
          next if file.end_with?("main.rb")
          next if abs == File.expand_path(__FILE__)
          next if @loaded_libs.include?(abs)

          require abs
          @loaded_libs << abs
        end
      end

      # Завантаження основного конфігу (ERB + YAML). Дозволяє Symbol.
      def load_default_config(path)
        return {} unless File.exist?(path)

        erb_result = ERB.new(File.read(path)).result
        YAML.safe_load(
          erb_result,
          aliases: true,
          permitted_classes: [Symbol],
          permitted_symbols: []
        ) || {}
      end

      # Завантаження всіх YAML із директорії (крім products). Дозволяє Symbol.
      def load_config(dir)
        return {} unless Dir.exist?(dir)

        merged = {}
        Dir.glob(File.join(dir, "**", "*.{yml,yaml}")).each do |file_path|
          # Пропускаємо YAML у config/yaml_config/products — це дані, не конфіги.
          next if file_path.include?(File.join("yaml_config", "products"))

          content = File.read(file_path)
          data = YAML.safe_load(
            content,
            aliases: true,
            permitted_classes: [Symbol],
            permitted_symbols: []
          ) || {}
          merged = deep_merge(merged, data)
        end
        merged
      end

      # Глибокий merge хешів
      def deep_merge(hash1, hash2)
        return hash2 unless hash1.is_a?(Hash) && hash2.is_a?(Hash)

        hash1.merge(hash2) do |_k, old_val, new_val|
          if old_val.is_a?(Hash) && new_val.is_a?(Hash)
            deep_merge(old_val, new_val)
          else
            new_val
          end
        end
      end

      # Завантажуємо всі конфіги
      def config(main_config_path, yaml_dir)
        base_config  = load_default_config(main_config_path)
        extra_config = load_config(yaml_dir)
        @config_data = deep_merge(base_config, extra_config)
      end

      # Красивий вивід конфігів
      def pretty_print_config_data
        puts JSON.pretty_generate(@config_data || {})
      end
    end
  end

  # Менеджер логів
  class LoggerManager
    class << self
      attr_reader :logger, :error_logger

      def setup(config_hash)
        logging_config = config_hash["logging"] || {}
        dir = logging_config["directory"] || "logs"
        FileUtils.mkdir_p(dir)

        files = logging_config["files"] || {}
        app_log_file   = File.join(dir, files["application_log"] || "app.log")
        error_log_file = File.join(dir, files["error_log"] || "error.log")

        level_str = logging_config["level"] || "INFO"
        level = case level_str.to_s.upcase
                when "DEBUG" then Logger::DEBUG
                when "WARN"  then Logger::WARN
                when "ERROR" then Logger::ERROR
                else Logger::INFO
                end

        @logger = Logger.new(app_log_file, "daily")
        @logger.level = level
        @error_logger = Logger.new(error_log_file, "daily")
        @error_logger.level = Logger::ERROR
      end

      def log_processed_file(message)
        ensure_loggers
        @logger.info(message)
      end

      def log_error(message)
        ensure_loggers
        @error_logger.error(message)
      end

      private

      def ensure_loggers
        @logger ||= Logger.new($stdout)
        @error_logger ||= Logger.new($stderr)
      end
    end
  end
end
