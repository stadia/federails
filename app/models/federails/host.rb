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

        new_record = entry.new_record?
        entry.sync!
        entry
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        recover_from_domain_race(domain, new_record)
      rescue Fediverse::NodeInfo::NoActivityPubError
        Federails.logger.info { "#{domain} does not provide ActivityPub service" }
      rescue Federails::Utils::JsonRequest::UnhandledResponseStatus, Faraday::SSLError, Faraday::ConnectionFailed, Faraday::TimeoutError => e
        Federails.logger.info { "Error connecting to #{domain}: '#{e.message}'" }
      end

      private

      # Recover from a concurrent insert of the same domain by returning the host
      # created by the competing job. Re-raise when it is not this race: the entry
      # was not a fresh insert, or no host with that domain exists.
      #: (String, bool) -> Federails::Host
      def recover_from_domain_race(domain, new_record)
        raise unless new_record

        find_by(domain: domain) || raise
      end
    end
  end
end
