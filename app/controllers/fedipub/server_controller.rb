# rbs_inline: enabled

module Fedipub
  class ServerController < ::ActionController::Base # rubocop:disable Rails/ApplicationController
    include Pagy::Method
    include Pundit::Authorization
    include Fedipub::ServerHelper

    before_action :verify_request_signature!
    after_action :verify_authorized

    protect_from_forgery with: :null_session
    helper Fedipub::ServerHelper

    rescue_from ActiveRecord::RecordNotFound, with: :error_not_found
    rescue_from Fedipub::Actor::TombstonedError,
                Fedipub::DataEntity::TombstonedError,
                with: :error_gone

    def self.require_signature?
      false
    end

    private

    # Optional GET/HEAD requests have only unsigned-request permissions and do not use signer identity for access.
    # Skip verification entirely to avoid fetching or storing an untrusted signer for these public reads.
    # Required signatures and non-GET/HEAD requests are verified; a verification failure returns 401.
    def verify_request_signature!
      require_signature = ServerController.require_signature?
      return if !require_signature && (request.get? || request.head?)

      Fediverse::Signature.verify!(request: request, require_signature: require_signature)
    rescue Fediverse::Signature::BadSignature => e
      log_signature_failure(e)
      head :unauthorized
    end

    def log_signature_failure(error, **details)
      Fedipub.logger.warn do
        {
          message:         "Signature verification failed: #{error.message}",
          remote_ip:       request.remote_ip,
          path:            request.fullpath,
          signature_input: request.headers['Signature-Input'],
          key_id:          request.headers['Signature'].to_s[/keyId="([^"]*)"/, 1],
          **details,
        }
      end
    end

    def error_fallback(exception, fallback_message, status)
      message = exception&.message || fallback_message
      respond_to do |format|
        format.jrd { head status }
        format.xrd { head status }
        format.activitypub { head status }
        format.nodeinfo { head status }
        format.json { render json: { error: message }, status: status }
        format.html { raise exception }
      end
    end

    def error_not_found(exception = nil)
      error_fallback(exception, 'Resource not found', :not_found)
    end

    def error_gone(exception = nil)
      skip_authorization
      error_fallback(exception, 'Resource is gone', :gone)
    end

    def render_serialized(resource_class, object, content_type:, status: :ok, location: nil, params: {})
      render_options = {
        json:         resource_class.new(object, params: params).serializable_hash,
        status:       status,
        content_type: content_type,
      }
      render_options[:location] = location if location
      render(**render_options)
    end
  end
end
