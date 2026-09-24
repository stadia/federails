module Fedipub
  # Definition for a single local Application Actor, which represents the instance/server itself.
  #
  # Keys from this actor are used to sign outgoing GET requests.
  module ApplicationActor
    extend ActiveSupport::Concern

    APPLICATION_ACTOR_ATTRIBUTES = {
      username:   '__application',
      actor_type: 'Application',
      entity:     nil,
      local:      true,
    }.freeze

    class_methods do
      def application_actor
        find_or_create_by!(APPLICATION_ACTOR_ATTRIBUTES)
      end
    end

    def application_actor?
      APPLICATION_ACTOR_ATTRIBUTES.all? { |attribute, value| attributes[attribute.to_s] == value }
    end
  end
end
