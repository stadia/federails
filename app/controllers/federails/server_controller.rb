module Federails
  class ServerController < ::ActionController::Base # rubocop:disable Rails/ApplicationController
    include Pagy::Method
    include Pundit::Authorization
    include Federails::ServerHelper

    after_action :verify_authorized

    protect_from_forgery with: :null_session
    helper Federails::ServerHelper

    rescue_from ActiveRecord::RecordNotFound, with: :error_not_found
    rescue_from Federails::Actor::TombstonedError,
                Federails::DataEntity::TombstonedError,
                with: :error_gone

    private

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
      error_fallback(exception, 'Resource is gone', :gone)
    end

    def render_serialized(resource_class, object, status: :ok, content_type:, location: nil, params: {})
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
