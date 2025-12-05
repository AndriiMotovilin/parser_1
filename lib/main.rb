
require_relative "my_application_motovilin"

MyApplicationMotovilin::AppConfigLoader.load_libs

config_data = MyApplicationMotovilin::AppConfigLoader.config(
  "config/default_config.yaml",
  "config/yaml_config"
)

puts "=== Loaded configuration (JSON) ==="
MyApplicationMotovilin::AppConfigLoader.pretty_print_config_data
puts "==================================="

MyApplicationMotovilin::LoggerManager.setup(config_data)
MyApplicationMotovilin::LoggerManager.log_processed_file("Application started from main.rb")


BooksScraper.run(config_data)

MyApplicationMotovilin::LoggerManager.log_processed_file("Application finished successfully")
