FactoryBot.define do
  factory :following_activity, class: 'Federails::Activity' do
    actor factory: [:distant_actor]
    # Create the following and return the Create activity
    initialize_with { create(:following, actor: actor).follow_activity }
  end
end
