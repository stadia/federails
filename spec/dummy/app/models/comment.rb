class Comment < ApplicationRecord
  validates :content, presence: true, allow_blank: false
  validates :post, presence: true, allow_blank: false, unless: :parent_id

  belongs_to :user
  belongs_to :post, optional: true
  belongs_to :parent, optional: true, class_name: 'Comment', inverse_of: :answers
  has_many :answers, class_name: 'Comment', foreign_key: :parent_id

  scope :parents, -> { where parent_id: nil }
end
