require 'fediverse/node_info'

module Federails
  class Host < ApplicationRecord
    attribute :protocols, :json
    attribute :services, :json

    validates :domain, presence: true, allow_blank: false, uniqueness: true

    # No "dependent" option here as this is not a hard reference, and we want to keep the actors if the host gets deleted
    has_many :actors, class_name: 'Federails::Actor', primary_key: :domain, foreign_key: :server, inverse_of: :host # rubocop:disable Rails/HasManyOrHasOneDependent

    scope :same_app, -> { where software_name: Configuration.app_name }
    scope :same_app_and_version, -> { same_app.where app_version: Configuration.app_version }

    def same_app?
      software_name == Configuration.app_name
    end

    def same_app_and_version?
      software_name == Configuration.app_name && app_version == Configuration.app_version
    end

    # Update from remote data
    def sync!
      update! Fediverse::NodeInfo.fetch(domain)
    end

    class << self
      # Creates or update a Host
      #
      # @param domain              [String] Domain to check
      # @param min_update_interval [Integer, ActiveSupport::Duration] Minimum amount of seconds since the last update to fetch fresh data
      def create_or_update(domain, min_update_interval: 0)
        entry = find_or_initialize_by domain: domain
        return if min_update_interval && entry.persisted? && (entry.updated_at + min_update_interval) > Time.current

        entry.sync!

        entry
      rescue Fediverse::NodeInfo::NoActivityPubError
        Rails.logger.info { "#{domain} does not provide ActivityPub service" }
      rescue Federails::Utils::JsonRequest::UnhandledResponseStatus, Faraday::SSLError => e
        Rails.logger.info { "Error connecting to #{domain}: '#{e.message}'" }
      end
    end
  end
end
