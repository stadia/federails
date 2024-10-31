module Federails
  class ClientController < Federails.configuration.base_client_controller.constantize
    include Pundit::Authorization

    layout Federails.configuration.app_layout if Federails.configuration.app_layout
  end
end
