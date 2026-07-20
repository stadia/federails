require 'rails_helper'
require 'pundit/rspec'

RSpec.describe Fedipub::Client::ActivityPolicy, type: :policy do
  let(:signed_in_user) { FactoryBot.create :user }
  let(:scope) { Fedipub::Client::ActivityPolicy::Scope.new(nil, Fedipub::Activity).resolve }

  permissions '.scope' do
    it 'returns all the activities' do
      FactoryBot.create_list :following, 2, :to_distant, actor: signed_in_user.fedipub_actor

      expect(scope.count).to eq 2
    end
  end

  permissions :index? do
    let(:policy_subject) { Fedipub::Activity }

    it_behaves_like 'an action for everyone'
  end

  permissions :feed? do
    let(:policy_subject) { Fedipub::Activity }

    it_behaves_like 'an action for federable instances only'
  end
end
