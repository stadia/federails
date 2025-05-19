class Comment < ApplicationRecord
  include Federails::DataEntity
  include FederatedAndSoftDeletable

  acts_as_federails_data handles:                 'Note',
                         actor_entity_method:     :user,
                         should_federate_method:  :federate?,
                         soft_deleted_method:     :soft_deleted?,
                         soft_delete_date_method: :deleted_at?

  validates :content, presence: true, allow_blank: false
  validates :post, presence: true, allow_blank: false, unless: :parent_id

  belongs_to :user, optional: true
  belongs_to :post, optional: true
  belongs_to :parent, optional: true, class_name: 'Comment', inverse_of: :answers
  has_many :answers, class_name: 'Comment', foreign_key: :parent_id, inverse_of: :parent, dependent: :destroy

  scope :parents, -> { where parent_id: nil }

  def to_activitypub_object
    Federails::DataTransformer::Note.to_federation self,
                                                   content: content
  end

  def self.handle_federated_object?(hash)
    # Only replies notes should be saved as Comment
    hash['inReplyTo'].present?
  end

  def self.from_activitypub_object(hash)
    raise 'No parent defined in object' if hash['inReplyTo'].blank?

    attrs = Federails::Utils::Object.timestamp_attributes(hash)
                                    .merge federated_url: hash['id'],
                                           content:       hash['content']

    parent_or_post = Federails::Utils::Object.find_or_create! hash['inReplyTo']

    if parent_or_post.is_a? Post
      attrs[:post] = parent_or_post
    elsif parent_or_post.is_a? Comment
      attrs[:parent] = parent_or_post
    end

    attrs
  end

  def federate?
    true
  end
end
