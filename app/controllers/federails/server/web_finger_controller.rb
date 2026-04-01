# rbs_inline: enabled

require 'fediverse/webfinger'

module Federails
  module Server
    class WebFingerController < Federails::ServerController
      def find
        skip_authorization

        resource = params.require(:resource)
        case resource
        when %r{^https?://.+}
          @user = Federails::Actor.find_by_federation_url!(resource).entity
        when /^acct:.+/
          actor = Federails::Actor.find_local_by_username(username)
          raise Federails::Actor::TombstonedError if actor&.tombstoned?

          @user = actor&.entity
        end
        raise ActiveRecord::RecordNotFound if @user.nil?

        render_serialized(
          Federails::Server::WebFingerResource,
          Federails::Server::WebFingerPayload.new(
            subject:           resource,
            self_href:         @user.federails_actor.federated_url,
            profile_href:      @user.federails_actor.profile_url,
            remote_follow_url: remote_follow_url
          ),
          content_type: Mime[:jrd]
        )
      end

      def host_meta
        skip_authorization

        render formats: [:xrd]
      end

      # TODO: complete missing endpoints

      private

      def username
        return @username if instance_variable_defined? :@username

        account = Fediverse::Webfinger.split_account params.require(:resource)
        # Fail early if user don't _seems_ local
        raise ActiveRecord::RecordNotFound unless account && Fediverse::Webfinger.local_user?(account)

        @username = account[:username]
      end
    end
  end
end
