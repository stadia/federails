require 'rails_helper'
require 'pundit/rspec'

RSpec.describe Federails::Client::ActivityPolicy, type: :policy do
  let(:signed_in_user) { FactoryBot.create :user }
  let(:scope) { Federails::Client::ActivityPolicy::Scope.new(nil, Federails::Activity).resolve }

  permissions '.scope' do
    it 'returns all the activities' do
      FactoryBot.create_list :following, 2, target_actor: signed_in_user.actor

      expect(scope.count).to eq 2
    end
  end

  permissions :index? do
    let(:policy_subject) { Federails::Activity }

    it_behaves_like 'an action for everyone'
  end

  permissions :feed? do
    let(:policy_subject) { Federails::Activity }

    it_behaves_like 'an action for federable instances only'
  end
end
