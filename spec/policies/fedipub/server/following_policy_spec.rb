require 'rails_helper'

RSpec.describe Fedipub::Server::FollowingPolicy, type: :policy do
  let(:user) { FactoryBot.create :user }
  let(:signed_in_user) { FactoryBot.create :user }
  let(:scope) { Fedipub::Server::FollowingPolicy::Scope.new(nil, Fedipub::Following).resolve }
  let(:following) { FactoryBot.create :following, actor: signed_in_user.fedipub_actor, target_actor: user.fedipub_actor }

  permissions '.scope' do
    it 'returns all the followings' do
      following
      expect(scope.count).to eq 1
    end
  end

  permissions :show? do
    let(:policy_subject) { following }

    it_behaves_like 'an action for everyone'
  end
end
