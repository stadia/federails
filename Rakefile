require 'bundler/setup'

APP_RAKEFILE = File.expand_path('spec/dummy/Rakefile', __dir__)
load 'rails/tasks/engine.rake'

load 'rails/tasks/statistics.rake'

require 'bundler/gem_tasks'

namespace :sig do
  desc 'Generate RBS signatures from rbs-inline annotations (sig/generated)'
  task rbs: :environment do
    sh 'bundle exec rbs-inline --output=sig/generated app lib'
  end
end
