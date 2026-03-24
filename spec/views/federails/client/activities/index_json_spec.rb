require 'rails_helper'

RSpec.describe 'federails/client/activities/index', type: :view do
  it 'renders an array of activities as json' do
    activity = FactoryBot.create(:activity, :create)
    assign(:activities, [activity])

    render template: 'federails/client/activities/index', formats: [:json]

    json = JSON.parse(rendered)
    expect(json).to match([
      include(
        'id' => activity.id,
        'action' => activity.action,
        'actor_id' => activity.actor_id
      )
    ])
  end
end
