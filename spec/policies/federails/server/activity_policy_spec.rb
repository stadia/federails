require 'rails_helper'

RSpec.describe Federails::Server::ActivityPolicy, type: :policy do
  let(:signed_in_user) { FactoryBot.create :user }
  let(:scope) { Federails::Server::ActivityPolicy::Scope.new(nil, Federails::Activity).resolve }

  permissions '.scope' do
    it 'returns all the activities' do
      # This will create two activities
      FactoryBot.create_list :following, 2, target_actor: signed_in_user.federails_actor

      expect(scope.count).to eq 2
    end
  end

  permissions :index? do
    let(:policy_subject) { Federails::Activity }

    it_behaves_like 'an action for everyone'
  end
end
