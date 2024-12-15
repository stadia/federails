FactoryBot.define do
  factory :post do
    title { Faker::Quote.fortune_cookie }
    content { Faker::Lorem.paragraph }

    user

    trait :distant do
      user { nil }
      federails_actor factory: :distant_actor
      federated_url { "https://example.com/content/#{rand(1...10_000)}" }
    end
  end
end
