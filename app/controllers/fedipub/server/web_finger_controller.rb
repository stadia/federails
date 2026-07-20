require 'fediverse/webfinger'

module Fedipub
  module Server
    class WebFingerController < Fedipub::ServerController
      def find
        skip_authorization

        resource = params.require(:resource)
        case resource
        when %r{^https?://.+}
          @user = Fedipub::Actor.find_by_federation_url!(resource).entity # rubocop:disable Rails/DynamicFindBy
        when /^acct:.+/
          actor = Fedipub::Actor.find_local_by_username(username)
          raise Fedipub::Actor::TombstonedError if actor&.tombstoned?

          @user = actor&.entity
        end
        raise ActiveRecord::RecordNotFound if @user.nil?

        render formats: [:jrd]
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
