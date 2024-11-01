require 'rails_helper'
require 'pundit/rspec'

RSpec.describe Federails::Client::ActorPolicy, type: :policy do
  let(:signed_in_user) { FactoryBot.create :user }
  let(:other_actor) { FactoryBot.create(:user).actor }
  let(:scope) { Federails::Client::ActorPolicy::Scope.new(nil, Federails::Actor).resolve }

  permissions '.scope' do
    it 'returns all the actors' do
      FactoryBot.create_list :user, 2
      FactoryBot.create :distant_actor

      # Plus the one created in the "before :suite" in rails helper
      expect(scope.count).to eq 4
    end
  end

  permissions :index? do
    let(:policy_subject) { Federails::Actor }

    it_behaves_like 'an action for everyone'
  end

  permissions :show? do
    let(:policy_subject) { other_actor }

    it_behaves_like 'an action for everyone'
  end
end
