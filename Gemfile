# frozen_string_literal: true

source "https://rubygems.org"

ruby "3.3.8"

gem 'dspy'
gem 'dotenv'

group :test do
  gem 'rspec', '~> 3.13'
  gem 'vcr', '~> 6.2'
  gem 'webmock', '~> 3.23'  # Required for VCR
end

group :development, :test do
  gem 'pry'
  gem 'pry-byebug'
end
