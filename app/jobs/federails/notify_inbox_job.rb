require 'fediverse/notifier'

module Federails
  class NotifyInboxJob < ApplicationJob
    retry_on Federails::TemporaryDeliveryError, wait: lambda { |executions, exception|
      exception.respond_to?(:retry_after) && exception.retry_after.to_i.positive? ? exception.retry_after : (executions**3) + 5
    }, attempts: 6
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
