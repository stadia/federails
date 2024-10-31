require 'federails/version'
require 'federails/engine'
require 'federails/configuration'

# rubocop:disable Style/ClassVars
module Federails
  mattr_reader :configuration
  @@configuration = Configuration

  # Make factories available
  config.factory_bot.definition_file_paths += [File.expand_path('spec/factories', __dir__)] if defined?(FactoryBotRails)

  def self.configure
    yield @@configuration
  end

  def self.config_from(name) # rubocop:disable Metrics/MethodLength
    config = Rails.application.config_for name
    [
      :app_name,
      :app_version,
      :force_ssl,
      :site_host,
      :site_port,
      :enable_discovery,
      :open_registrations,
      :app_layout,
      :server_routes_path,
      :client_routes_path,
      :remote_follow_url_method,
      :user_name_field, # @deprecated
      :user_username_field, # @deprecated
      :base_client_controller,
    ].each { |key| Configuration.send :"#{key}=", config[key] if config.key?(key) }
  end
end
# rubocop:enable Style/ClassVars
