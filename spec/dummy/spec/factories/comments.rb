FactoryBot.define do
  factory :comment do
    content { Faker::Lorem.paragraph }

    user
    post

    trait :distant do
      user { nil }
      federails_actor factory: :distant_actor
      federated_url { "https://example.com/content/#{rand(1...10_000)}" }
    end
  end
end
