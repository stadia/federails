FactoryBot.define do
  factory :host, class: 'Federails::Host' do
    domain { Faker::Internet.domain_name }

    trait :handles_activitypub do
      protocols { ['activitypub'] }
    end

    # trait :same_app do
    #   handles_activitypub
    #   software_name {  } # Fill in your software name
    # end

    # trait :same_app_and_version do
    #   handles_activitypub
    #   software_name {  } # Fill in your software name
    #   software_version {  } # Fill in your software version
    # end
  end
end
