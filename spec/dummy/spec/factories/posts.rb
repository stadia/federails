FactoryBot.define do
  factory :post do
    title { Faker::Quote.fortune_cookie }
    content { Faker::Lorem.paragraph }

    user
  end
end
