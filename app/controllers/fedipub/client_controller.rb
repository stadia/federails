module Fedipub
  class ClientController < Fedipub.configuration.base_client_controller.constantize
    include Pundit::Authorization

    after_action :verify_authorized

    layout Fedipub.configuration.app_layout if Fedipub.configuration.app_layout
  end
end
