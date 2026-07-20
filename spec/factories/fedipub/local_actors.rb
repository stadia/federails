FactoryBot.define do
  factory :local_actor, class: 'Federails::Actor' do
    initialize_with do
      # Create an "actor entity" and pick the actor from here
      #
      # If the actor creation is conditional, make sure to adapt the actor entity creation accordingly
      create(:user) # <- Adapt the "actor entity" for your app
        .federails_actor
    end
  end
end
