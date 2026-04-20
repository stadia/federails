# rbs_inline: enabled

require 'fediverse/request'

module Fediverse
  class Inbox
    module DeleteHandler
      class << self
        # Early-dispatch path invoked from Inbox.dispatch_request before dereferencing.
        # Handles the Delete case where the target object may already be gone remotely.
        #: (Hash[String, untyped]) -> untyped
        def dispatch_delete_request(payload)
          object_ref = payload['object'].is_a?(String) ? payload['object'] : payload['object']['id']
          object = Federails::Utils::Object.find_distant_object_in_all(object_ref)
          return if object.blank?

          object.run_callbacks(:on_federails_delete_requested)
        end

        # Triggers on_federails_delete_requested callback on the matching local object.
        #: (Hash[String, untyped]) -> void
        def handle_delete_request(activity)
          object = Federails::Utils::Object.find_distant_object_in_all(activity['object'])
          return if object.blank?

          object.run_callbacks(:on_federails_delete_requested)
        end

        # Triggers on_federails_undelete_requested callback when an Undo+Delete is received.
        #: (Hash[String, untyped]) -> void
        def handle_undelete_request(activity)
          delete_activity = Request.dereference(activity['object'])
          return if delete_activity.blank?

          object = Federails::Utils::Object.find_distant_object_in_all(delete_activity['object'])
          return if object.blank?

          object.run_callbacks(:on_federails_undelete_requested)
        end
      end
    end
  end
end

Fediverse::Inbox.register_handler 'Delete', '*', Fediverse::Inbox::DeleteHandler, :handle_delete_request
Fediverse::Inbox.register_handler 'Undo', 'Delete', Fediverse::Inbox::DeleteHandler, :handle_undelete_request
