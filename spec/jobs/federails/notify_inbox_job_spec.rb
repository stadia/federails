require 'rails_helper'

module Federails
  RSpec.describe NotifyInboxJob, type: :job do
    let(:actor) { FactoryBot.create :local_actor }
    let(:activity) { Activity.create!(actor: actor, entity: actor, action: 'Create') }
    let(:inbox_url) { 'https://remote.example.com/inbox' }

    context 'without inbox_url (enqueue mode)' do
      before do
        allow(Fediverse::Notifier).to receive(:enqueue_deliveries)
      end

      it 'calls enqueue_deliveries with the activity' do
        described_class.perform_now(activity)
        expect(Fediverse::Notifier).to have_received(:enqueue_deliveries).with(activity)
      end
    end

    context 'with inbox_url (single delivery mode)' do
      before do
        allow(Fediverse::Notifier).to receive(:deliver_to_inbox)
      end

      it 'calls deliver_to_inbox with the activity and inbox_url' do
        described_class.perform_now(activity, inbox_url)
        expect(Fediverse::Notifier).to have_received(:deliver_to_inbox).with(activity, inbox_url)
      end
    end

    context 'when a PermanentDeliveryError is raised' do
      before do
        allow(Fediverse::Notifier).to receive(:deliver_to_inbox).and_raise(
          Federails::PermanentDeliveryError.new('Gone', response_code: 410, inbox_url: inbox_url)
        )
      end

      it 'discards the job without retrying' do
        expect { described_class.perform_now(activity, inbox_url) }.not_to raise_error
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
