# lib/tasks/scrape_books.rake
# frozen_string_literal: true

require_relative "../my_application_motovilin"
require_relative "../books_scraper"

namespace :books do
  desc "Scrape books from Books to Scrape and save to CSV/JSON"
  task :scrape do
    MyApplicationMotovilin::AppConfigLoader.load_libs
    config_data = MyApplicationMotovilin::AppConfigLoader.config(
      "config/default_config.yaml",
      "config/yaml_config"
    )
    MyApplicationMotovilin::LoggerManager.setup(config_data)
    BooksScraper.run(config_data)
  end
end
