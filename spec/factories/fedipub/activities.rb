FactoryBot.define do
  factory :activity, class: 'Federails::Activity' do
    actor factory: [:local_actor]
    entity factory: [:local_actor]
    action { 'X' }

    trait :create do
      action { 'Create' }
    end
  end
end
