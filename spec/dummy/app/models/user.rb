class User < ApplicationRecord
  include Federails::ActorEntity

  acts_as_federails_actor username_field:    :id,
                          name_field:        :email,
                          user_count_method: :user_count

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :posts, dependent: :destroy
  has_many :comments, dependent: :destroy

  after_followed :accept_follow
  def accept_follow(follow); end

  after_follow_accepted :follow_accepted
  def follow_accepted(follow); end

  def self.user_count(range)
    if range.nil?
      # No range, return total user count
      User.count
    else
      # Normally we'd want to return *active* users in the range, but we don't have that in this example
      # so we will list users that have been changed.
      User.where(updated_at: range).count
    end
  end

  def to_activitypub_object
    {
      '@context':         {
        toot:               'http://joinmastodon.org/ns#',
        attributionDomains: {
          '@id':   'toot:attributionDomains',
          '@type': '@id',
        },
      },
      attributionDomains: [
        'example.com',
      ],
    }
  end
end
