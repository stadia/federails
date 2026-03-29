# rbs_inline: enabled

require 'fediverse/inbox/activity_handler'

module Fediverse
  class Inbox
    module LikeHandler
      extend ActivityHandler

      class << self
        def handle_like(activity)
          process_activity(activity, 'Like')
        end

        def handle_undo_like(activity)
          process_undo_activity(activity, 'Like')
        end
      end
    end
  end
end
