# typed: ignore
# rbs_inline: enabled

module Fedipub
  class ClientController < Fedipub.configuration.base_client_controller.constantize
    include Pundit::Authorization

    after_action :verify_authorized

    layout Fedipub.configuration.app_layout if Fedipub.configuration.app_layout

    private

    def render_serialized(resource_class, object, status: :ok, location: nil, params: {})
      render_options = {
        json:   resource_class.new(object, params: params).serializable_hash,
        status: status,
      }
      render_options[:location] = location if location
      render(**render_options)
    end
  end
end
