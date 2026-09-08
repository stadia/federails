module Fediverse
  module Signature
    class << self
      def sign(sender:, request:)
        Fediverse::Signature::DraftCavage12.sign(sender: sender, request: request)
      end

      def verify(sender:, request:)
        Fediverse::Signature::DraftCavage12.verify(sender: sender, request: request)
      end

      def signature_payload(request:, headers:)
        headers.split.map do |signed_header_name|
          if signed_header_name == '(request-target)'
            "(request-target): #{request.http_method} #{URI.parse(request.path).path}"
          else
            "#{signed_header_name}: #{request.headers[signed_header_name.capitalize]}"
          end
        end.join("\n")
      end
    end
  end
end

require 'fediverse/signature/draft_cavage12'
