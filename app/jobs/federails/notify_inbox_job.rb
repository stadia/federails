require 'fediverse/notifier'

module Federails
  class NotifyInboxJob < ApplicationJob
    retry_on Federails::TemporaryDeliveryError, wait: :polynomially_longer, attempts: 6
    discard_on Federails::PermanentDeliveryError

    def perform(activity)
      activity = Activity.includes(:entity, actor: :entity).find(activity.id)
      Fediverse::Notifier.post_to_inboxes(activity)
    end
  end
end
