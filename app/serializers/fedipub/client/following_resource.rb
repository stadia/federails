# rbs_inline: enabled

module Fedipub
  module Client
    class FollowingResource < BaseResource
      attributes :id, :actor_id, :target_actor_id, :status, :created_at, :updated_at
    end
  end
end
