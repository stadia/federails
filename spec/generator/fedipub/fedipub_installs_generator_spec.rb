require 'rails_helper'

RSpec.describe 'Federails::Install', type: :generator do
  it 'copies all the client views' do # rubocop:disable RSpec/ExampleLength
    output = `bundle exec rails generate fedipub:install --pretend --skip`
             .split("\n")
             .map(&:strip)
             .join("\n")

    expect(output).to eq <<~TXT.strip
      skip  spec/dummy/config/fedipub.yml
      identical  spec/dummy/config/initializers/fedipub.rb
    TXT
  end
end
