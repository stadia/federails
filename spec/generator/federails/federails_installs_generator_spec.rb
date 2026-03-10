require 'rails_helper'

RSpec.describe 'Federails::Install', type: :generator do
  it 'copies all the client views' do
    output = `bundle exec rails generate federails:install --pretend --skip`
             .split("\n")
             .map(&:strip)
             .join("\n")

    expect(output).to eq <<~TXT.strip
      skip  spec/dummy/config/federails.yml
      identical  spec/dummy/config/initializers/federails.rb
    TXT
  end
end
