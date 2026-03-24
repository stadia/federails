require 'rails_helper'

RSpec.describe Federails::Client::ActivityResource do
  it 'renders an array of activities as json' do
    activity = FactoryBot.create :activity, :create
    json = JSON.parse(described_class.new([activity]).serialize)
    expect(json).to match([
                            include(
                              'id'       => activity.id,
                              'action'   => activity.action,
                              'actor_id' => activity.actor_id
                            ),
                          ])
  end
end
