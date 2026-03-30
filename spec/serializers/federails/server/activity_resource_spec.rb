require 'rails_helper'

RSpec.describe Federails::Server::ActivityResource do
  let(:local_actor) { FactoryBot.create :local_actor }
  let(:distant_actor) { FactoryBot.create :distant_actor }

  def render_activity(activity, params: {})
    described_class.new(activity, params: params).serializable_hash.deep_stringify_keys
  end

  context 'when rendering a Follow activity' do
    let(:follow) { FactoryBot.create :following, actor: local_actor, target_actor: distant_actor }
    let(:json_result) { render_activity(follow.follow_activity) }

    it 'has an id' do
      expect(json_result['id']).to eq "http://localhost/federation/actors/#{local_actor.uuid}/activities/#{follow.follow_activity.uuid}"
    end

    it 'has Follow type' do
      expect(json_result['type']).to eq 'Follow'
    end

    it 'references actor by URL' do
      expect(json_result['actor']).to eq local_actor.federated_url
    end

    it 'references target actor by URL' do
      expect(json_result['object']).to eq distant_actor.federated_url
    end

    it 'is addressed only to the target actor' do
      expect(json_result['to']).to eq [distant_actor.federated_url]
    end

    it 'is not cced to anyone else' do
      expect(json_result).not_to have_key 'cc'
    end
  end

  context 'when rendering an Undo activity' do
    let(:follow) { FactoryBot.create :following, actor: local_actor, target_actor: distant_actor }
    let(:undo) do
      follow.destroy
      Federails::Activity.find_by action: 'Undo'
    end
    let(:json_result) { render_activity(undo) }

    it 'has Undo type' do
      expect(json_result['type']).to eq('Undo').and(eq(undo.action))
    end

    it 'references actor by URL' do
      expect(json_result['actor']).to eq follow.actor.federated_url
    end

    it 'references includes original Follow as object' do
      uuid = follow.follow_activity.uuid
      expect(json_result.dig('object', 'id')).to eq "http://localhost/federation/actors/#{local_actor.uuid}/activities/#{uuid}"
    end

    it 'is addressed only to the followed actor' do
      expect(json_result['to']).to eq [distant_actor.federated_url]
    end

    it 'is not cced to anyone else' do
      expect(json_result).not_to have_key 'cc'
    end
  end

  context 'when rendering an Accept activity' do
    let(:follow) { FactoryBot.create :following, actor: local_actor, target_actor: distant_actor }
    let(:accept) do
      follow.accept!
      Federails::Activity.find_by action: 'Accept'
    end
    let(:json_result) { render_activity(accept) }

    it 'has Accept type' do
      expect(json_result['type']).to eq('Accept').and(eq(accept.action))
    end

    it 'is performed by the target actor' do
      expect(json_result['actor']).to eq follow.target_actor.federated_url
    end

    it 'references includes original Follow as object' do
      expect(json_result['object']).to eq "#{local_actor.federated_url}/followings/#{follow.uuid}"
    end

    it 'is addressed only to the original actor' do
      expect(json_result['to']).to eq [local_actor.federated_url]
    end

    it 'is not cced to anyone else' do
      expect(json_result).not_to have_key 'cc'
    end
  end

  context 'when rendering a Like activity' do
    let(:post) { FactoryBot.create :post, :distant }
    let(:activity) do
      FactoryBot.create(
        :activity,
        actor: local_actor,
        entity: post,
        action: 'Like',
        to: [post.federails_actor.federated_url],
        cc: []
      )
    end
    let(:json_result) { render_activity(activity) }

    it 'serializes the liked object as its URI' do
      expect(json_result['object']).to eq post.federated_url
    end
  end

  context 'when rendering an Undo of a Like activity' do
    let(:post) { FactoryBot.create :post, :distant }
    let(:like_activity) do
      FactoryBot.create(
        :activity,
        actor: local_actor,
        entity: post,
        action: 'Like',
        to: [post.federails_actor.federated_url],
        cc: []
      )
    end
    let(:undo_activity) do
      FactoryBot.create(
        :activity,
        actor: local_actor,
        entity: like_activity,
        action: 'Undo',
        to: [post.federails_actor.federated_url],
        cc: []
      )
    end
    let(:json_result) { render_activity(undo_activity) }

    it 'keeps the nested Like object as the original URI' do
      expect(json_result.dig('object', 'object')).to eq post.federated_url
    end
  end

  context 'when rendering a public Create activity' do
    let!(:activity) { FactoryBot.create :activity, :create, entity: local_actor }
    let(:json_result) { render_activity(activity) }

    it 'has an id' do
      expect(json_result['id']).to eq "http://localhost/federation/actors/#{activity.actor.uuid}/activities/#{activity.uuid}"
    end

    it 'is addressed to the public collection' do
      expect(json_result['to']).to include Fediverse::Collection::PUBLIC
    end

    it "is cced to the actor's followers" do
      expect(json_result['cc']).to include "http://localhost/federation/actors/#{activity.actor.uuid}/followers"
    end

    it "is cced to the entity's followers if local" do
      expect(json_result['cc']).to include "http://localhost/federation/actors/#{local_actor.uuid}/followers"
    end
  end

  context 'when rendering an activity with audience, bto, and bcc' do
    let!(:activity) do
      FactoryBot.create(
        :activity,
        :create,
        entity:   local_actor,
        audience: ['https://example.com/groups/team'],
        bto:      ['https://example.com/users/private'],
        bcc:      ['https://example.com/users/hidden']
      )
    end
    let(:json_result) { render_activity(activity) }

    it 'includes audience in the serialized activity' do
      expect(json_result['audience']).to eq(['https://example.com/groups/team'])
    end

    it 'does not expose bto' do
      expect(json_result).not_to have_key('bto')
    end

    it 'does not expose bcc' do
      expect(json_result).not_to have_key('bcc')
    end
  end
end
