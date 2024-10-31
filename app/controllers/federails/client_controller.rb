module Federails
  class ClientController < ActionController::Base
    include Pundit::Authorization

    layout Federails.configuration.app_layout if Federails.configuration.app_layout
  end
end
