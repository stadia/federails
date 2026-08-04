require 'rails_helper'

module Fedipub
  RSpec.describe Fedipub do
    it 'includes preloaded security vocabulary' do
      expect(JSON::LD::Context::PRELOADED).to have_key('http://w3id.org/security/v1')
    end
  end
end
