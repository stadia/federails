require 'fediverse/notifier'

module Federails
  class NotifyInboxJob < ApplicationJob
    retry_on Federails::TemporaryDeliveryError, wait: :polynomially_longer, attempts: 6
    discard_on Federails::PermanentDeliveryError do |job, error|
      activity = job.arguments.first
      DeadLetter.record_failure(activity: activity, target_inbox: error.inbox_url, error: error.message)
    end

    def perform(activity)
      activity = Activity.includes(:entity, actor: :entity).find(activity.id)
      Fediverse::Notifier.post_to_inboxes(activity)
    end
  end
end
