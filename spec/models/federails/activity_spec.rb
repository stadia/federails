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
          title:   'A reply',
          content: 'reply content',
          user_id: FactoryBot.create(:user).id
        )
        allow(entity).to receive(:federation_reply_recipients).and_return(['https://remote.example/users/original'])

        activity = described_class.create(actor: alice, entity: entity, action: 'Create')
        expect(activity.cc).to include('https://remote.example/users/original')
      end

      it 'deduplicates recipients when followers_url overlaps with reply recipients' do
        entity = Fixtures::Classes::FakeDataModel.create!(
          title:   'A reply',
          content: 'reply content',
          user_id: FactoryBot.create(:user).id
        )
        allow(entity).to receive(:federation_reply_recipients).and_return([alice.followers_url])

        activity = described_class.create(actor: alice, entity: entity, action: 'Create')
        expect(activity.cc.count(alice.followers_url)).to eq 1
      end
    end

    describe 'serializing to field' do
      let(:addresses) { ['https://example.com/@abc123', 'https://example.social/@def456'] }
      let(:activity) { described_class.create!(actor: alice, entity: bob, action: 'Create', to: addresses) }

      it 'preserves explicitly set to addresses' do
        a = described_class.find(activity.id)
        expect(a.to).to eq addresses
      end
    end

    describe 'serializing cc field' do
      let(:addresses) { ['https://example.com/@abc123', 'https://example.social/@def456'] }
      let(:activity) { described_class.create!(actor: alice, entity: bob, action: 'Create', cc: addresses) }

      it 'preserves explicitly set cc addresses alongside defaults' do
        a = described_class.find(activity.id)
        addresses.each do |addr|
          expect(a.cc).to include(addr)
        end
      end

      it 'merges default followers into cc' do
        a = described_class.find(activity.id)
        expect(a.cc).to include(alice.followers_url)
      end
    end

    context 'when partial addressing is provided' do
      it 'does not merge followers when to is not public' do
        custom_to = ['https://remote.example/users/someone']
        activity = described_class.create!(actor: alice, entity: alice, action: 'Create', to: custom_to)

        expect(activity.to).to eq custom_to
        expect(activity.cc).to be_nil
      end

      it 'merges followers into cc when to defaults to public via bto' do
        activity = described_class.create!(
          actor: alice, entity: alice, action: 'Create',
          bto: ['https://remote.example/users/secret']
        )

        expect(activity.to).to eq [Fediverse::Collection::PUBLIC]
        expect(activity.cc).to include(alice.followers_url)
      end

      it 'includes reply recipients even for directed activities' do
        entity = Fixtures::Classes::FakeDataModel.create!(
          title:   'A reply',
          content: 'reply content',
          user_id: FactoryBot.create(:user).id
        )
        allow(entity).to receive(:federation_reply_recipients).and_return(['https://remote.example/users/original'])

        activity = described_class.create!(
          actor: alice, entity: entity, action: 'Create',
          to: ['https://remote.example/users/original']
        )

        expect(activity.cc).to include('https://remote.example/users/original')
      end

      it 'includes reply recipients and followers when cc is explicitly provided for public activity' do
        entity = Fixtures::Classes::FakeDataModel.create!(
          title:   'A reply',
          content: 'reply content',
          user_id: FactoryBot.create(:user).id
        )
        allow(entity).to receive(:federation_reply_recipients).and_return(['https://remote.example/users/original'])

        activity = described_class.create!(
          actor: alice, entity: entity, action: 'Create',
          cc: ['https://other.example/users/mentioned']
        )

        expect(activity.cc).to include('https://remote.example/users/original')
        expect(activity.cc).to include('https://other.example/users/mentioned')
        expect(activity.cc).to include(alice.followers_url)
      end
    end
  end
end
