require 'fediverse/notifier'

module Federails
  class NotifyInboxJob < ApplicationJob
    queue_as :default

    def perform(activity)
      activity = Activity.includes(:actor, :entity).find(activity.id)
      Fediverse::Notifier.post_to_inboxes(activity)
    end
  end
end
