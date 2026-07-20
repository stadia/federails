module Federails
  module Utils
    module Context
      class << self
        def generate(additional: nil)
          activity_streams = 'https://www.w3.org/ns/activitystreams'
          additional.nil? ? activity_streams : [activity_streams, additional].flatten.compact
        end
      end
    end
  end
end
