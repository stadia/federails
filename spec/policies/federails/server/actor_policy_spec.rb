require 'rails_helper'

RSpec.describe Federails::Server::ActorPolicy, type: :policy do
  let(:signed_in_user) { FactoryBot.create :user }
  let(:scope) { Federails::Server::ActivityPolicy::Scope.new(nil, Federails::Actor).resolve }

  permissions '.scope' do
    it 'returns all the users' do
      FactoryBot.create :user

      # Plus the one created in the "before :suite" in rails helper
      expect(scope.count).to eq 2
    end
  end

  permissions :show? do
    let(:policy_subject) { signed_in_user.actor }

    it_behaves_like 'an action for everyone'
  end
end
