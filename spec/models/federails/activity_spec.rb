require 'rails_helper'

module Federails
  RSpec.describe Activity, type: :model do
    let(:alice) { FactoryBot.create :local_actor }
    let(:bob) { FactoryBot.create :local_actor }

    context 'when using default addressing' do
      it 'has public collection in to: field' do
        activity = described_class.create(actor: alice, entity: alice, action: 'Create')
        expect(activity.to).to eq [Fediverse::Collection::PUBLIC]
      end

      it 'has actor followers collection in cc: field' do
        activity = described_class.create(actor: alice, entity: alice, action: 'Create')
        expect(activity.cc).to include alice.followers_url
      end

      it 'has entity followers collection in cc: field if it has one' do
        activity = described_class.create(actor: alice, entity: bob, action: 'Create')
        expect(activity.cc).to include bob.followers_url
      end

      it 'includes federation_reply_recipients from the entity' do
        entity = Fixtures::Classes::FakeDataModel.create!(
          title: 'A reply',
          content: 'reply content',
          user_id: FactoryBot.create(:user).id
        )
        allow(entity).to receive(:federation_reply_recipients).and_return(['https://remote.example/users/original'])

        activity = described_class.create(actor: alice, entity: entity, action: 'Create')
        expect(activity.cc).to include('https://remote.example/users/original')
      end

      it 'deduplicates recipients when followers_url overlaps with reply recipients' do
        entity = Fixtures::Classes::FakeDataModel.create!(
          title: 'A reply',
          content: 'reply content',
          user_id: FactoryBot.create(:user).id
        )
        allow(entity).to receive(:federation_reply_recipients).and_return([alice.followers_url])

        activity = described_class.create(actor: alice, entity: entity, action: 'Create')
        expect(activity.cc.count(alice.followers_url)).to eq 1
      end
    end

    [:to, :cc].each do |attr|
      describe "serializing #{attr} field" do
        let(:addresses) { ['https://example.com/@abc123', 'https://example.social/@def456'] }
        let(:activity) { described_class.create!(:actor => alice, :entity => bob, :action => 'Create', attr => addresses) }

        it 'serializes and deserializes multiple addresses correctly' do
          a = described_class.find(activity.id)
          expect(a.send(attr)).to eq addresses
        end
      end
    end
  end
end
