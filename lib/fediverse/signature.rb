module Fediverse
  module Signature
    class << self
      def sign(sender:, request:, legacy_signature: false)
        if legacy_signature
          Fediverse::Signature::DraftCavage12.sign(sender: sender, request: request)
        else
          Fediverse::Signature::Rfc9421.sign(sender: sender, request: request)
        end
      end

      def verify(sender:, request:)
        Fediverse::Signature::DraftCavage12.verify(sender: sender, request: request)
      end

      def signature_payload(request:, headers:)
        headers = headers.split if headers.is_a?(String)
        headers.map do |header|
          case header
          when '(request-target)'
            "(request-target): #{request.http_method} #{URI.parse(request.path).path}"
          else
            "#{header}: #{request.headers[header.capitalize]}"
          end
        end.join("\n")
      end
    end
  end
end

require 'fediverse/signature/draft_cavage12'
require 'fediverse/signature/rfc9421'
