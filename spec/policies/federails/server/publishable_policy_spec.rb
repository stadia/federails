require 'rails_helper'

RSpec.describe Federails::Server::PublishablePolicy, type: :policy do
  let(:signed_in_user) { FactoryBot.create :user }
  let(:published) { Fixtures::Classes::FakeArticleDataModel.create title: 'The title', content: 'Some content', user: FactoryBot.create(:user) }
  let(:scope) { Federails::Server::PublishablePolicy::Scope.new(nil, published).resolve }

  permissions '.scope' do
    it 'is not implemented' do
      expect { scope }.to raise_error NotImplementedError
    end
  end

  permissions :show? do
    let(:policy_subject) { published }

    it_behaves_like 'an action for everyone'
  end
end
