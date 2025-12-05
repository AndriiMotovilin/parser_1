# lib/main.rb
# frozen_string_literal: true

require_relative "my_application_motovilin"

# 1. Автопідключення бібліотек
MyApplicationMotovilin::AppConfigLoader.load_libs

# 2. Завантаження конфігів (default + всі YAML у config/yaml_config)
config_data = MyApplicationMotovilin::AppConfigLoader.config(
  "config/default_config.yaml",
  "config/yaml_config"
)

# 3. Вивід конфігів у JSON (для перевірки етапу 2)
puts "=== Loaded configuration (JSON) ==="
MyApplicationMotovilin::AppConfigLoader.pretty_print_config_data
puts "==================================="

# 4. Налаштування логування
MyApplicationMotovilin::LoggerManager.setup(config_data)
MyApplicationMotovilin::LoggerManager.log_processed_file("Application started from main.rb")

# 5. Запуск парсера
BooksScraper.run(config_data)

MyApplicationMotovilin::LoggerManager.log_processed_file("Application finished successfully")
