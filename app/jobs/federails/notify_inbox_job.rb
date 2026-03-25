require 'fediverse/notifier'

module Federails
  class NotifyInboxJob < ApplicationJob
    def perform(activity)
      activity = Activity.includes(:entity, actor: :entity).find(activity.id)
      Fediverse::Notifier.post_to_inboxes(activity)
    end
  end
end
