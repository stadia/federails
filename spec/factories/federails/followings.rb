FactoryBot.define do
  factory :following, class: 'Federails::Following' do
    actor factory: [:distant_actor]
    target_actor factory: [:local_actor]

    trait :outgoing do
      actor factory: [:local_actor]
      target_actor factory: [:distant_actor]
    end

    trait :accepted do
      after :create, &:accept!
    end
  end
end
