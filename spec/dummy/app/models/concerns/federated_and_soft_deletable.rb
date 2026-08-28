module FederatedAndSoftDeletable
  extend ActiveSupport::Concern

  included do
    scope :deleted, -> { where.not deleted_at: nil }
    scope :not_deleted, -> { where deleted_at: nil }

    on_fedipub_delete_requested :handle_fedipub_delete_request!
    on_fedipub_undelete_requested :handle_fedipub_undelete_request!
  end

  def soft_deleted?
    deleted_at.present?
  end

  def soft_delete!
    update! deleted_at: Time.current
    # Manually create the delete activity
    create_fedipub_activity 'Delete' if local_fedipub_entity?
  end

  private

  def handle_fedipub_delete_request!
    update! deleted_at: Time.current
  end

  def handle_fedipub_undelete_request!
    self.deleted_at = nil
    fedipub_sync!
    save!
  end
end
