require 'fediverse/notifier'

module Federails
  class NotifyInboxJob < ApplicationJob
    def perform(activity)
      activity.reload
      Fediverse::Notifier.post_to_inboxes(activity)
    end
  end
end
