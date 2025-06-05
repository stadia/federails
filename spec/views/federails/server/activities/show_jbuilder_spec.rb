require 'rails_helper'

RSpec.describe 'federails/server/activities/show', type: :view do
  let(:local_actor) { FactoryBot.create :local_actor }
  let(:distant_actor) { FactoryBot.create :distant_actor }

  # enable ServerHelper methods for tests
  helper Federails::ServerHelper

  context 'when rendering a Follow activity' do
    let(:follow) { FactoryBot.create :following, actor: local_actor, target_actor: distant_actor }
    let(:json_result) do
      assign(:activity, follow.follow_activity)
      render
      JSON.parse(rendered)
    end

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
  end

  context 'when rendering an Undo activity' do
    let(:follow) { FactoryBot.create :following, actor: local_actor, target_actor: distant_actor }
    let(:undo) do
      follow.destroy
      Federails::Activity.find_by action: 'Undo'
    end
    let(:json_result) do
      assign(:activity, undo)
      render
      JSON.parse(rendered)
    end

    it 'has Undo type' do
      expect(json_result['type']).to eq('Undo').and(eq(undo.action))
    end

    it 'references actor by URL' do
      expect(json_result['actor']).to eq follow.actor.federated_url
    end

    it 'references includes original Follow as object' do
      uuid = follow.follow_activity.uuid
      expect(json_result['object']).to eq({
                                            'id'     => "http://localhost/federation/actors/#{local_actor.uuid}/activities/#{uuid}",
                                            'type'   => 'Follow',
                                            'actor'  => local_actor.federated_url,
                                            'object' => distant_actor.federated_url,
                                          })
    end
  end
end
