require 'fediverse/notifier'

module Federails
  class NotifyInboxJob < ApplicationJob
    rescue_from Federails::TemporaryDeliveryError do |exception|
      current_attempt = executions

      if current_attempt < 6
        wait = if exception.respond_to?(:retry_after) && exception.retry_after.to_i.positive?
                 exception.retry_after
               else
                 (current_attempt**3) + 5
               end

        retry_job wait: wait, error: exception
      else
        raise exception
      end
    end
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
