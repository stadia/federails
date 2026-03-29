# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:each) do
    Federails::Configuration.verify_signatures = false
  end

  config.after(:each) do
    Federails::Configuration.verify_signatures = true
  end
end
