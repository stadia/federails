module Federails
  # rubocop:disable Style/ClassVars
  module Configuration
    # Application name, used in well-known and nodeinfo endpoints
    mattr_accessor :app_name
    @@app_name = nil

    # Application version, used in well-known and nodeinfo endpoints
    mattr_accessor :app_version
    @@app_version = nil

    # Force https urls in various rendered content (currently in webfinger views)
    mattr_accessor :force_ssl
    @@force_ssl = nil

    # Site hostname
    mattr_reader :site_host
    @@site_host = nil

    # Site port
    mattr_reader :site_port
    @@site_port = nil

    # Whether to enable ".well-known" and "nodeinfo" endpoints
    mattr_accessor :enable_discovery
    @@enable_discovery = true

    # Does the site allow open registrations? (only used for nodeinfo reporting)
    mattr_accessor :open_registrations
    @@open_registrations = false

    # Site port
    mattr_accessor :app_layout
    @@app_layout = nil

    # User class name
    # @deprecated Kept for upgrade compatibility only
    mattr_accessor :user_class
    @@user_class = '::User'

    # Route path for the federation URLs (to "Federails::Server::*" controllers)
    mattr_accessor :server_routes_path
    @@server_routes_path = :federation

    # Route path for the webapp URLs (to "Federails::Client::*" controllers)
    mattr_accessor :client_routes_path
    @@client_routes_path = :app

    # Route method for remote-following requests
    mattr_accessor :remote_follow_url_method
    @@remote_follow_url_method = 'federails.new_client_following_url'

    # Method to use for links to user profiles
    # @deprecated Set profile_url_method option on acts_as_federails_actor instead
    mattr_accessor :user_profile_url_method
    @@user_profile_url_method = nil

    # Attribute in the user model to use as the user's name
    # @deprecated Set name_field option on acts_as_federails_actor instead
    #
    # It only have sense if you have a separate username attribute
    mattr_accessor :user_name_field
    @@user_name_field = nil

    # Attribute in the user model to use as the username for local actors
    # @deprecated Set username_field option on acts_as_federails_actor instead
    mattr_accessor :user_username_field
    @@user_username_field = :id

    ##
    # @return [String] Table used for user model
    # @deprecated Kept for upgrade compatibility only
    def self.user_table
      @@user_class&.constantize&.table_name
    end

    def self.site_host=(value)
      @@site_host = value
      Federails::Engine.routes.default_url_options[:host] = value
    end

    def self.site_port=(value)
      @@site_port = value
      Federails::Engine.routes.default_url_options[:port] = value
    end

    # List of entity types
    mattr_reader :entity_types
    @@entity_types = {}

    def self.register_entity(klass, config = {})
      @@entity_types[klass.name] = config.merge(class: klass)
    end
  end
  # rubocop:enable Style/ClassVars
end
