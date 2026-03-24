module Federails
  module Server
    class BaseResource
      include Alba::Resource

      def select(_key, value)
        !value.nil?
      end
    end
  end
end
