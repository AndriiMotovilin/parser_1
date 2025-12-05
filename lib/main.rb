# lib/main.rb
# frozen_string_literal: true

require_relative "my_application_motovilin"
require_relative "configurator"

# 1. Автопідключення бібліотек
MyApplicationMotovilin::AppConfigLoader.load_libs

# 2. Завантажуємо конфіги
config_data = MyApplicationMotovilin::AppConfigLoader.config(
  "config/default_config.yaml",
  "config/yaml_config"
)

# 3. Виводимо конфіги у JSON (для перевірки)
puts "=== Loaded configuration (JSON) ==="
MyApplicationMotovilin::AppConfigLoader.pretty_print_config_data
puts "==================================="

# 4. Налаштовуємо логування
MyApplicationMotovilin::LoggerManager.setup(config_data)

# 5. Створюємо Configurator на основі run_options
run_options = config_data["run_options"] || {}
configurator = MyApplicationMotovilin::Configurator.new
configurator.configure(run_options)

puts "Available configurator keys: #{MyApplicationMotovilin::Configurator.available_methods}"
puts "Current config: #{configurator.config.inspect}"

MyApplicationMotovilin::LoggerManager.log_processed_file(
  "Configurator in main.rb: #{configurator.config.inspect}"
)

# 6. Запускаємо парсер із урахуванням Configurator
BooksScraper.run(config_data, configurator)

MyApplicationMotovilin::LoggerManager.log_processed_file("Application finished successfully")
