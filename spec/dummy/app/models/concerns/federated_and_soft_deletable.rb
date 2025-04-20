module FederatedAndSoftDeletable
  extend ActiveSupport::Concern

  included do
    scope :deleted, -> { where.not deleted_at: nil }
    scope :not_deleted, -> { where deleted_at: nil }

    on_federails_delete_requested :handle_federails_delete_request!
    on_federails_undelete_requested :handle_federails_undelete_request!
  end

  def soft_deleted?
    deleted_at.present?
  end

  def soft_delete!
    update! deleted_at: Time.current
    # Manually create the delete activity
    create_federails_activity 'Delete' if local_federails_entity?
  end

  private

  def handle_federails_delete_request!
    update! deleted_at: Time.current
  end

  def handle_federails_undelete_request!
    self.deleted_at = nil
    federails_sync!
    save!
  end
end
