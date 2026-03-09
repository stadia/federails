require 'rails_helper'
require 'fediverse/request'

module Fediverse
  RSpec.describe Collection do
    context 'when fetching a remote collection URL' do
      let(:url) { 'https://mamot.fr/users/mtancoigne/following' }

      it 'loads expected length' do
        VCR.use_cassette 'fediverse/collection/get_followers_200' do
          collection = described_class.fetch(url)
          expect(collection.total_items).to eq 19
        end
      end

      it 'has an id' do
        VCR.use_cassette 'fediverse/collection/get_followers_200' do
          collection = described_class.fetch(url)
          expect(collection.id).to eq 'https://mamot.fr/users/mtancoigne/following'
        end
      end

      it 'has an type' do
        VCR.use_cassette 'fediverse/collection/get_followers_200' do
          collection = described_class.fetch(url)
          expect(collection.type).to eq 'OrderedCollection'
        end
      end

      it 'fetches complete collection' do
        VCR.use_cassette 'fediverse/collection/get_followers_200' do
          collection = described_class.fetch(url)
          expect(collection.length).to eq 19
        end
      end

      it 'loads actual collection items' do
        VCR.use_cassette 'fediverse/collection/get_followers_200' do
          collection = described_class.fetch(url)
          expect(collection.first).to eq 'https://mastodon.me.uk/users/Floppy'
        end
      end
    end

    context 'when fetching something that is not a collection' do
      let(:url) { 'https://mamot.fr/users/mtancoigne' }

      it 'raises unhandled response error' do
        VCR.use_cassette 'fediverse/request/get_actor_200' do
          expect { described_class.fetch(url) }.to raise_error(Errors::NotACollection)
        end
      end
    end

    context 'when fetching a missing remote collection' do
      let(:url) { 'https://example.com/following' }

      it 'raises unhandled response error' do
        VCR.use_cassette 'fediverse/collection/get_followers_404' do
          expect { described_class.fetch(url) }.to raise_error(Federails::Utils::JsonRequest::UnhandledResponseStatus)
        end
      end
    end

    context 'when fetching an empty collection' do
      let(:url) { 'https://mamot.fr/users/mtancoigne/collections/featured' }

      it 'is empty' do
        VCR.use_cassette 'fediverse/collection/get_featured_200' do
          collection = described_class.fetch(url)
          expect(collection).to be_empty
        end
      end
    end

    context 'when limiting collection pagination' do
      let(:url) { 'https://example.com/collection' }

      it 'stops fetching after max_pages is reached' do
        allow(Fediverse::Request).to receive(:dereference).with(url).and_return({
                                                                                  'id'         => url,
                                                                                  'type'       => 'OrderedCollection',
                                                                                  'totalItems' => 5,
                                                                                  'first'      => 'https://example.com/collection?page=1',
                                                                                })

        (1..4).each do |page|
          allow(Fediverse::Request).to receive(:dereference).with("https://example.com/collection?page=#{page}").and_return({
                                                                                                                              'orderedItems' => ["https://example.com/actor/#{page}"],
                                                                                                                              'next'         => (page == 4 ? nil : "https://example.com/collection?page=#{page + 1}"),
                                                                                                                            })
        end

        collection = described_class.fetch(url, max_pages: 3)

        expect(collection.length).to eq 3
        expect(collection).to eq([
                                   'https://example.com/actor/1',
                                   'https://example.com/actor/2',
                                   'https://example.com/actor/3',
                                 ])
      end
    end
  end
end
