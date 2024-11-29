class Post < ApplicationRecord
  validates :title, presence: true, allow_blank: false
  validates :content, presence: true, allow_blank: false

  belongs_to :user
  has_many :comments
end
