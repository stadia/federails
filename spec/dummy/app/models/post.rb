class Post < ApplicationRecord
  include Federails::DataEntity
  include FederatedAndSoftDeletable

  acts_as_federails_data handles:                 'Note',
                         actor_entity_method:     :user,
                         soft_deleted_method:     :soft_deleted?,
                         soft_delete_date_method: :deleted_at?

  validates :title, presence: true, allow_blank: false
  validates :content, presence: true, allow_blank: false

  belongs_to :user, optional: true
  has_many :comments

  def to_activitypub_object
    Federails::DataTransformer::Note.to_federation self,
                                                   name:    title,
                                                   content: content
  end

  def self.handle_federated_object?(hash)
    # Only "top level" notes should be saved as Post; replies are handled by Comment
    hash['inReplyTo'].blank?
  end

  def self.from_activitypub_object(hash)
    Federails::Utils::Object.timestamp_attributes(hash)
                            .merge federated_url: hash['id'],
                                   title:         hash['published'] || 'A post',
                                   content:       hash['content']
  end
end
