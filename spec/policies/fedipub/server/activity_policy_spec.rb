require 'rails_helper'

RSpec.describe Fedipub::Server::ActivityPolicy, type: :policy do
  let(:signed_in_user) { FactoryBot.create :user }
  let(:scope) { Fedipub::Server::ActivityPolicy::Scope.new(nil, Fedipub::Activity).resolve }

  permissions '.scope' do
    it 'returns all the activities' do
      # This will create two activities
      FactoryBot.create_list :following, 2, :to_distant, actor: signed_in_user.fedipub_actor

      expect(scope.count).to eq 2
    end
  end

  permissions :index? do
    let(:policy_subject) { Fedipub::Activity }

    it_behaves_like 'an action for everyone'
  end
end
