require 'rails_helper'

module Federails
  RSpec.describe NotifyInboxJob, type: :job do
    let(:actor) { FactoryBot.create :local_actor }
    let(:activity) { Activity.create!(actor: actor, entity: actor, action: 'Create') }
    let(:inbox_url) { 'https://remote.example.com/inbox' }

    before do
      allow(Fediverse::Notifier).to receive(:post_to_inboxes)
    end

    it 'calls post_to_inboxes with the activity' do
      described_class.perform_now(activity)
      expect(Fediverse::Notifier).to have_received(:post_to_inboxes).with(activity)
    end

    context 'when a PermanentDeliveryError is raised' do
      before do
        allow(Fediverse::Notifier).to receive(:post_to_inboxes).and_raise(
          Federails::PermanentDeliveryError.new('Gone', response_code: 410, inbox_url: inbox_url)
        )
      end

      it 'records a dead letter and does not retry' do
        expect do
          described_class.perform_now(activity)
        end.to change(DeadLetter, :count).by(1)

        dl = DeadLetter.last
        expect(dl.activity).to eq activity
        expect(dl.target_inbox).to eq inbox_url
        expect(dl.last_error).to eq 'Gone'
      end
    end

    context 'when a TemporaryDeliveryError is raised' do
      it 'is configured to retry' do
        retries = described_class.rescue_handlers.select { |h| h[0].include?('Federails::TemporaryDeliveryError') }
        expect(retries).not_to be_empty
      end
    end
  end
end
