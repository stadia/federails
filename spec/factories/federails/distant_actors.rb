FactoryBot.define do
  factory :distant_actor, class: 'Federails::Actor' do
    entity { nil }
    federated_url { "https://example.com/actors/#{rand(1...10_000)}" }
    username { Faker::Internet.username separators: ['-', '_'] }
    server { 'example.com' }
    inbox_url { "#{federated_url}/inbox" }
    outbox_url { "#{federated_url}/outbox" }
    followers_url { "#{federated_url}/followers" }
    followings_url { "#{federated_url}/followings" }
    profile_url { "https://example.com/users/#{federated_url.split('/').last}" }
  end
end
