require 'rails_helper'

require 'federails/utils/object'

module Federails
  module Utils
    RSpec.describe Object do
      describe '.find_or_initialize' do
        context 'when object is a local entity' do
          let(:entity) { Fixtures::Classes::FakeDataModel.create! user: FactoryBot.create(:user), title: 'the title', content: 'the content' }
          let(:url) { entity.federated_url }

          context 'when entity exists' do
            it 'returns the entity' do
              result = described_class.find_or_initialize url
              aggregate_failures do
                expect(result).to be_a Fixtures::Classes::FakeDataModel
                expect(result.id).to eq entity.id
              end
            end
          end

          context 'when entity does not exist' do
            let(:url) { "#{entity.federated_url}000" }

            it 'returns nil' do
              expect(described_class.find_or_initialize(url)).to be_nil
            end
          end
        end

        context 'when object is a distant entity' do
          let(:distant_actor) { FactoryBot.build :distant_actor }
          let(:entity) { Fixtures::Classes::FakeDataModel.build federails_actor_id: distant_actor.id, federated_url: 'https://example.com/data/1', title: 'A title', content: 'the content' }
          let(:url) { entity.federated_url }

          context 'when it exists locally' do
            before do
              distant_actor.save!
              entity.save!

              allow(Fediverse::Request).to receive(:dereference).with(url).and_return({ 'id' => url, 'type' => 'CustomNote', 'actor' => distant_actor.federated_url, 'content' => 'the content' })
            end

            it 'returns the entity' do
              result = described_class.find_or_initialize url

              aggregate_failures do
                expect(result).to be_a Fixtures::Classes::FakeArticleDataModel
                expect(result.id).to eq entity.id
              end
            end
          end

          context 'when it does not exist locally' do
            context 'when it exists remotely' do
              before do
                allow(Fediverse::Request).to receive(:dereference).with(url).and_return({ 'id' => url, 'type' => 'CustomNote', 'actor' => distant_actor.federated_url, 'content' => 'the content' })
                allow(Federails::Actor).to receive(:find_by_federation_url).with(distant_actor.federated_url).and_return(distant_actor)
              end

              it 'returns the initialized entity' do
                result = described_class.find_or_initialize url

                aggregate_failures do
                  expect(result).to be_a Fixtures::Classes::FakeArticleDataModel
                  expect(result.id).to be_nil
                end
              end

              context 'when actor is missing from database' do
                it 'initializes the actor' do
                  result = described_class.find_or_initialize(url)

                  aggregate_failures do
                    expect(result.federails_actor).to be_a Federails::Actor
                    expect(result.federails_actor).not_to be_persisted
                  end
                end
              end

              context 'when actor exists in database' do
                before do
                  distant_actor.save!
                end

                it 'does not create a new actor' do
                  expect { described_class.find_or_initialize(url) }.not_to change(Federails::Actor, :count)
                end
              end
            end

            context 'when it does not exists remotely' do
              before do
                allow(Fediverse::Request).to receive(:dereference).with(url).and_return(nil)
              end

              it 'returns nil' do
                expect(described_class.find_or_initialize(url)).to be_nil
              end
            end
          end
        end
      end

      describe '.find_or_create' do
        context 'when entity does not exist' do
          let(:url) { 'https://example.com/notes/1' }

          it 'raises an error' do
            allow(described_class).to receive(:find_or_initialize).with(url).and_return(nil)

            expect { described_class.find_or_create! url }.to raise_error ActiveRecord::RecordNotFound
          end
        end
      end

      describe '.find_distant_object_in_all' do
        let(:entities) do
          # Noise
          FactoryBot.create(:distant_actor).tap do |actor|
            Fixtures::Classes::FakeArticleDataModel.create(title: 'Not the right one', content: 'Hello world', federated_url: 'https://some_example.com/posts/1', federails_actor: actor)
          end

          [
            FactoryBot.create(:distant_actor),
            Fixtures::Classes::FakeArticleDataModel.create!(
              title:           'The right one',
              content:         'Hello world',
              federated_url:   'https://some_example.com/posts/10',
              federails_actor: FactoryBot.create(:distant_actor)
            ),
          ]
        end

        it 'returns the right object' do
          aggregate_failures do
            entities.each do |entity|
              expect(described_class.find_distant_object_in_all(entity.federated_url)).to eq entity
            end
          end
        end
      end
    end
  end
end
