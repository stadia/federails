require 'rails_helper'
require 'pundit/rspec'

# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe Federails::Client::FollowingPolicy, type: :policy do
  let(:user) { FactoryBot.create :user }
  let(:signed_in_user) { FactoryBot.create :user }
  let(:unrelated_user) { FactoryBot.create :user }
  let(:scope) { Federails::Client::FollowingPolicy::Scope.new(signed_in_user, Federails::Following).resolve }
  let(:following) { FactoryBot.create :following, actor: user.federails_actor, target_actor: signed_in_user.federails_actor }

  permissions '.scope' do
    it 'returns the followings where user is involved' do
      following
      FactoryBot.create :following, actor: signed_in_user.federails_actor, target_actor: user.federails_actor
      FactoryBot.create :following, actor: user.federails_actor, target_actor: unrelated_user.federails_actor

      expect(scope.count).to eq 2
    end
  end

  permissions :create?, :follow? do
    let(:policy_subject) { Federails::Following }

    it_behaves_like 'an action for authenticated users only'
  end

  permissions :destroy? do
    let(:policy_subject) { following }

    it_behaves_like 'denies access when unauthenticated'

    context 'when authenticated' do
      it 'denies access to non-owner' do
        expect(described_class).not_to permit(unrelated_user, following)
      end

      it 'grants access to owner' do
        expect(described_class).to permit(signed_in_user, following)
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
