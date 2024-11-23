FactoryBot.define do
  factory :local_actor, class: 'Federails::Actor' do
    # Local actors needs an user, and gets created with one, so we create an user and return its actor
    initialize_with { create(:user).federails_actor }
  end
end
