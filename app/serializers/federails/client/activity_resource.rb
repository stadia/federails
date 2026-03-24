module Federails
  module Client
    class ActivityResource < BaseResource
      attributes :id, :entity_id, :entity_type, :action, :actor_id, :created_at
    end
  end
end
