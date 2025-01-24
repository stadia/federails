source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in federails.gemspec.
gemspec

# Dummy app
gem 'devise'
gem 'jbuilder'
gem 'sprockets-rails'
gem 'sqlite3'

# Linters
gem 'rubocop', '1.60.0'
gem 'rubocop-factory_bot', '2.25.1'
gem 'rubocop-faker', '1.1.0'
gem 'rubocop-performance', '1.20.2'
gem 'rubocop-rails', '2.23.1'
gem 'rubocop-rake', '0.6.0'
gem 'rubocop-rspec', '2.26.1'

# Testing
gem 'database_cleaner'
gem 'factory_bot_rails'
gem 'faker'
gem 'rspec-rails'
gem 'rspec-rails-api', '~> 0.8'
gem 'rspec-rfc-helper'
gem 'simplecov'
gem 'vcr'
gem 'webmock'

# Start debugger with binding.b [https://github.com/ruby/debug]
gem 'debug', '>= 1.0.0'

group :doc do
  gem 'jekyll'
  gem 'just-the-docs'
  gem 'sleeping_king_studios-yard', git: 'https://github.com/sleepingkingstudios/sleeping_king_studios-yard.git', branch: 'main'
  gem 'webrick', '~> 1.8' # Use Webrick as local content server.
  gem 'yard', '~> 0.9', require: false

  # Remove this once "just-the-docs" has an update with SASS deprecations fixed (after 0.10.0)
  # see: https://github.com/just-the-docs/just-the-docs/issues/1541#issuecomment-2401649789
  #
  # For now, compiling SCSS results in 1000+ lines of deprecation warnings leading to
  # plugins being hard to debug
  gem 'sass-embedded', '< 1.78.0'
end
