require 'federails/version'
require 'federails/engine'
require 'federails/configuration'

# rubocop:disable Style/ClassVars

# This module includes classes and methods related to Ruby on Rails: engine configuration, models, controllers, etc.
module Federails
  mattr_reader :configuration
  @@configuration = Configuration

  # Make factories available
  config.factory_bot.definition_file_paths += [File.expand_path('spec/factories', __dir__)] if defined?(FactoryBotRails)

  class << self
    def configure
      yield @@configuration
    end

    def config_from(name) # rubocop:disable Metrics/MethodLength
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
        :base_client_controller,
      ].each { |key| Configuration.send :"#{key}=", config[key] if config.key?(key) }
    end

    # @return [Boolean] True if the given model is a possible actor
    #
    # @example
    #   puts "Follow #{some_actor.name}" if actor_entity? current_user
    def actor_entity?(class_or_instance)
      Configuration.actor_types.key? class_or_instance_name(class_or_instance)
    end

    # @return [Hash] The configuration for the given actor entity
    def actor_entity(class_or_instance)
      klass = class_or_instance_name(class_or_instance)
      raise "#{klass} is not a configured actor entity" unless Configuration.actor_types.key?(klass)

      Configuration.actor_types[klass]
    end

    # @return [Boolean] True if the given model is a possible data entity
    def data_entity?(class_or_instance)
      Configuration.data_types.key? class_or_instance_name(class_or_instance)
    end

    # @return [Hash] The configuration for the given data entity
    def data_entity_configuration(class_or_instance)
      klass = class_or_instance_name(class_or_instance)
      raise "#{klass} is not a configured data entity" unless Configuration.data_types.key?(klass)

      Configuration.data_types[klass]
    end

    private

    # @return [String] Class name of the provided class or instance
    def class_or_instance_name(class_or_instance)
      case class_or_instance
      when String
        class_or_instance
      when Class
        class_or_instance.name
      else
        class_or_instance.class.name
      end
    end
  end
end
# rubocop:enable Style/ClassVars
