require 'rails_helper'

RSpec.describe Federails::Server::FollowingPolicy, type: :policy do
  let(:user) { FactoryBot.create :user }
  let(:signed_in_user) { FactoryBot.create :user }
  let(:scope) { Federails::Server::ActivityPolicy::Scope.new(nil, Federails::Following).resolve }
  let(:following) { FactoryBot.create :following, actor: signed_in_user.actor, target_actor: user.actor }

  permissions '.scope' do
    it 'returns all the followings' do
      following
      expect(scope.count).to eq 1
    end
  end

  permissions :show? do
    context 'when unauthenticated' do
      it 'grants access' do
        expect(described_class).to permit(nil, following)
      end
    end

    context 'when authenticated' do
      it 'grants access' do
        expect(described_class).to permit(signed_in_user, following)
      end
    end
  end
end
