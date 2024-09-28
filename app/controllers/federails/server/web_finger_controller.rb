require 'fediverse/webfinger'

module Federails
  module Server
    class WebFingerController < ServerController
      def find
        resource = params.require(:resource)
        case resource
        when %r{^https?://.+}
          @user = Federails::Actor.find_by_federation_url(resource)&.entity
        when /^acct:.+/
          Federails::Configuration.entity_types.each_value do |entity|
            @user ||= entity[:class].find_by(entity[:username_field] => username)
          end
        end
        raise ActiveRecord::RecordNotFound if @user.nil?

        render formats: [:jrd]
      end

      def host_meta
        render formats: [:xrd]
      end

      # TODO: complete missing endpoints

      private

      def username
        account = Fediverse::Webfinger.split_resource_account params.require(:resource)
        # Fail early if user don't _seems_ local
        raise ActiveRecord::RecordNotFound unless account && Fediverse::Webfinger.local_user?(account)

        account[:username]
      end
    end
  end
end
