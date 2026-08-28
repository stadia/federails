# frozen_string_literal: true

RSpec.configure do |config|
  config.before do
    Fedipub::Configuration.verify_signatures = false
  end

  config.after do
    Fedipub::Configuration.verify_signatures = true
  end
end
