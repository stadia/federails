module Federails
  # Model concern providing hooks for social activities handled on DataEntity models.
  module HandlesSocialActivities
    extend ActiveSupport::Concern

    # Class methods automatically included in the concern.
    module ClassMethods
      def on_federails_like_received(method_name = nil, **, &)
        register_social_callback(:on_federails_like_received, method_name, **, &)
      end

      def on_federails_undo_like_received(method_name = nil, **, &)
        register_social_callback(:on_federails_undo_like_received, method_name, **, &)
      end

      def on_federails_announce_received(method_name = nil, **, &)
        register_social_callback(:on_federails_announce_received, method_name, **, &)
      end

      def on_federails_undo_announce_received(method_name = nil, **, &)
        register_social_callback(:on_federails_undo_announce_received, method_name, **, &)
      end

      private

      def register_social_callback(callback_name, method_name = nil, **options, &block)
        if method_name
          set_callback(callback_name, **options) do |record|
            record.public_send(method_name, record.current_federails_activity_actor)
          end
        elsif block
          set_callback(callback_name, **options, &block)
        else
          raise ArgumentError, 'expected a callback method or block'
        end
      end
    end

    included do
      attr_accessor :current_federails_activity_actor

      define_callbacks :on_federails_like_received
      define_callbacks :on_federails_undo_like_received
      define_callbacks :on_federails_announce_received
      define_callbacks :on_federails_undo_announce_received
    end
  end
end
