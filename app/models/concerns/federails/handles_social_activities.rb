module Federails
  # Model concern providing hooks for social activities handled on DataEntity models.
  module HandlesSocialActivities
    extend ActiveSupport::Concern

    # Class methods automatically included in the concern.
    module ClassMethods
      def on_federails_like_received(*)
        set_callback(:on_federails_like_received, *)
      end

      def on_federails_undo_like_received(*)
        set_callback(:on_federails_undo_like_received, *)
      end

      def on_federails_announce_received(*)
        set_callback(:on_federails_announce_received, *)
      end

      def on_federails_undo_announce_received(*)
        set_callback(:on_federails_undo_announce_received, *)
      end
    end

    included do
      define_callbacks :on_federails_like_received
      define_callbacks :on_federails_undo_like_received
      define_callbacks :on_federails_announce_received
      define_callbacks :on_federails_undo_announce_received
    end
  end
end
