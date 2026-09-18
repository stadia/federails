# frozen_string_literal: true

RSpec.configure do |config|
  config.after do
    Fedipub::Configuration.verify_signatures = true
  end
end
