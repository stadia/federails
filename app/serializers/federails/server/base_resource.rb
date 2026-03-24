module Federails
  module Server
    class BaseResource
      include Alba::Resource

      # ActivityPub responses omit absent fields instead of rendering explicit nulls.
      def select(_key, value)
        !value.nil?
      end

      private

      def normalize_activitypub_hash(data)
        data.deep_dup.deep_transform_keys { |key| key.respond_to?(:to_sym) ? key.to_sym : key }
      end
    end
  end
end
