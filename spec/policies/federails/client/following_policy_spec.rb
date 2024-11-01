require 'rails_helper'
require 'pundit/rspec'

RSpec.describe Federails::Client::FollowingPolicy, type: :policy do
  let(:user) { FactoryBot.create :user }
  let(:signed_in_user) { FactoryBot.create :user }
  let(:unrelated_user) { FactoryBot.create :user }
  let(:scope) { Federails::Client::FollowingPolicy::Scope.new(signed_in_user, Federails::Following).resolve }
  let(:following) { FactoryBot.create :following, actor: user.actor, target_actor: signed_in_user.actor }

  permissions '.scope' do
    it 'returns the followings where user is involved' do
      following
      FactoryBot.create :following, actor: signed_in_user.actor, target_actor: user.actor
      FactoryBot.create :following, actor: user.actor, target_actor: unrelated_user.actor

      expect(scope.count).to eq 2
    end
  end

  permissions :create?, :follow? do
    context 'when unauthenticated' do
      it 'denies access' do
        expect(described_class).not_to permit(nil, Federails::Following)
      end
    end

    context 'when authenticated' do
      it 'grants access' do
        expect(described_class).to permit(signed_in_user, Federails::Following)
      end
    end
  end

  permissions :destroy? do
    context 'when unauthenticated' do
      it 'denies access' do
        expect(described_class).not_to permit(nil, following)
      end
    end

    context 'when authenticated' do
      it 'denies access to non-owners' do
        expect(described_class).not_to permit(unrelated_user, following)
      end

      it 'grants access to owner' do
        expect(described_class).to permit(signed_in_user, following)
      end
    end
  end
end
