# lib/tasks/scrape_books.rake
# frozen_string_literal: true

require_relative "../books_scraper"

namespace :books do
  desc "Scrape books from Books to Scrape and save to CSV/JSON"
  task :scrape do
    BooksScraper.run
  end
end
