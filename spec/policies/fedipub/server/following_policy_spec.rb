require 'rails_helper'

RSpec.describe Federails::Server::FollowingPolicy, type: :policy do
  let(:user) { FactoryBot.create :user }
  let(:signed_in_user) { FactoryBot.create :user }
  let(:scope) { Federails::Server::FollowingPolicy::Scope.new(nil, Federails::Following).resolve }
  let(:following) { FactoryBot.create :following, actor: signed_in_user.federails_actor, target_actor: user.federails_actor }

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
