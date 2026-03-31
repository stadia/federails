# frozen_string_literal: true

RSpec.configure do |config|
  config.before do
    Federails::Configuration.verify_signatures = false
  end

  config.after do
    Federails::Configuration.verify_signatures = true
  end
end
