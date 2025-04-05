FactoryBot.define do
  factory :following, class: 'Federails::Following' do
    # Default trait
    to_distant

    trait :to_distant do
      actor factory: [:local_actor]
      target_actor factory: [:distant_actor]
    end

    trait :to_local do
      actor factory: [:local_actor]
      target_actor factory: [:local_actor]
    end

    trait :incoming do
      federated_url { "https://example.com/followings/#{rand(1...10_000)}" }

      actor factory: [:distant_actor]
      target_actor factory: [:local_actor]
    end

    trait :accepted do
      after :create, &:accept!
    end
  end
end
