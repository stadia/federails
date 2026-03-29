# rbs_inline: enabled

require 'fediverse/inbox/activity_handler'

module Fediverse
  class Inbox
    module AnnounceHandler
      extend ActivityHandler

      class << self
        def handle_announce(activity)
          process_activity(activity, 'Announce')
        end

        def handle_undo_announce(activity)
          process_undo_activity(activity, 'Announce')
        end
      end
    end
  end
end
