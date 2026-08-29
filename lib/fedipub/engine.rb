# typed: true
# rbs_inline: enabled

require 'rails/engine'
require 'action_dispatch'

require 'fedipub/delivery_errors'

module Fedipub
  class Engine < ::Rails::Engine
    isolate_namespace Fedipub

    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot
      g.factory_bot dir: 'spec/factories'
    end
  end
end
