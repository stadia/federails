module Federails
  # Stores following data between actors
  class Following < ApplicationRecord
    include Federails::HasUuid

    enum :status, pending: 0, accepted: 1

    validates :target_actor_id, uniqueness: { scope: [:actor_id, :target_actor_id] }

    belongs_to :actor
    belongs_to :target_actor, class_name: 'Federails::Actor'
    has_many :activities, as: :entity, dependent: :destroy

    after_create :after_follow
    after_create :create_activity, if: :locally_instigated?
    after_update :after_follow_accepted
    after_destroy :destroy_activity, if: :locally_instigated?

    define_callbacks :on_federails_delete_requested

    set_callback :on_federails_delete_requested, -> { destroy! unless locally_instigated? }

    scope :with_actor, ->(actor) { where(actor_id: actor.id).or(where(target_actor_id: actor.id)) }

    def federated_url
      attributes['federated_url'].presence || Federails::Engine.routes.url_helpers.server_actor_following_url(actor_id: actor.to_param, id: to_param)
    end

    def accept!
      update! status: :accepted
      Activity.create! actor: target_actor, action: 'Accept', entity: self
    end

    def follow_activity
      Activity.find_by actor: actor, action: 'Follow', entity: target_actor
    end

    class << self
      def new_from_account(account, actor:)
        target_actor = Actor.find_or_create_by_account account
        new actor: actor, target_actor: target_actor
      end
    end

    private

    def locally_instigated?
      actor.local?
    end

    def after_follow
      return unless target_actor&.entity

      target_actor.entity.class.send(:dispatch_callback, :after_followed, target_actor.entity, self)
    end

    def after_follow_accepted
      return unless status_previously_changed? && status == 'accepted'
      return unless actor&.entity

      actor.entity.class.send(:dispatch_callback, :after_follow_accepted, actor.entity, self)
    end

    def create_activity
      Activity.create! actor: actor, action: 'Follow', entity: target_actor
    end

    def destroy_activity
      Activity.create! actor: actor, action: 'Undo', entity: follow_activity
    end
  end
end
