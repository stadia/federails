module Fediverse
  module Signature
    class Rfc9421
      class << self
        def sign(sender:, request:)
          request
        end

        def verify(sender:, request:)
          false
        end
      end
    end
  end
end
