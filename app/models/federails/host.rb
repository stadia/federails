# rbs_inline: enabled

require 'fediverse/node_info'

module Federails
  class Host < ApplicationRecord
    attribute :protocols, :json
    attribute :services, :json

    validates :domain, presence: true, allow_blank: false, uniqueness: true

    has_many :actors, class_name: 'Federails::Actor', primary_key: :domain, foreign_key: :server, inverse_of: :host, dependent: false

    scope :same_app, -> { where software_name: Configuration.app_name }
    scope :same_app_and_version, -> { same_app.where app_version: Configuration.app_version }

    #: () -> bool
    def same_app?
      software_name == Configuration.app_name
    end

    #: () -> bool
    def same_app_and_version?
      software_name == Configuration.app_name && app_version == Configuration.app_version
    end

    # Update from remote data
    #: () -> bool
    def sync!
      update! Fediverse::NodeInfo.fetch(domain)
    end

    class << self
      # Creates or update a Host
      #: (String, ?min_update_interval: Integer | ActiveSupport::Duration) -> Federails::Host?
      def create_or_update(domain, min_update_interval: 0)
        entry = find_or_initialize_by domain: domain
        return if min_update_interval && entry.persisted? && (entry.updated_at + min_update_interval) > Time.current

        entry.sync!

        entry
      rescue Fediverse::NodeInfo::NoActivityPubError
        Federails.logger.info { "#{domain} does not provide ActivityPub service" }
      rescue Federails::Utils::JsonRequest::UnhandledResponseStatus, Faraday::SSLError => e
        Federails.logger.info { "Error connecting to #{domain}: '#{e.message}'" }
      end
    end
  end
end
