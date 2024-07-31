module Federails
  module Entity
    extend ActiveSupport::Concern

    included do
      has_one :actor, class_name: 'Federails::Actor', as: :entity, dependent: :destroy

      after_create :create_actor

      private

      def create_actor
        Federails::Actor.create! entity: self
      end
    end
  end
end
