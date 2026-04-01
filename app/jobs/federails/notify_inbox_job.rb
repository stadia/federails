require 'fediverse/notifier'

module Federails
  class NotifyInboxJob < ApplicationJob
    retry_on Federails::TemporaryDeliveryError, wait: :polynomially_longer, attempts: 6
    discard_on Federails::PermanentDeliveryError

    def perform(activity, inbox_url = nil)
      activity = Activity.includes(:entity, actor: :entity).find(activity.id)

      if inbox_url
        Fediverse::Notifier.deliver_to_inbox(activity, inbox_url)
      else
        Fediverse::Notifier.enqueue_deliveries(activity)
      end
    end
  end
end
