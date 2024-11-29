FactoryBot.define do
  factory :post do
    title { Faker::Lorem.string }
    content { Faker::Lorem.paragraph }

    user
  end
end
