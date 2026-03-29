module Federails
  class DeadLetter < ApplicationRecord
    belongs_to :activity

    validates :target_inbox, presence: true
    validates :target_inbox, uniqueness: { scope: :activity_id }

    def self.record_failure(activity:, target_inbox:, error:)
      dl = find_or_initialize_by(activity: activity, target_inbox: target_inbox)
      dl.attempts += 1
      dl.last_error = error
      dl.last_attempted_at = Time.current
      dl.save!
      dl
    end
  end
end
