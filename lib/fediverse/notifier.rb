# rbs_inline: enabled

require 'fediverse/signature'

module Fediverse
  class Notifier
    MAX_COLLECTION_DEPTH = 3 #: Integer
    ACTIONS_REQUIRING_OBJECT = %w[Accept Add Announce Block Create Delete Flag Follow Like Move Reject Remove Undo Update].freeze
    PERMANENT_DELIVERY_STATUS_CODES = (400..499).to_a.freeze

    class << self
      # Enqueues a separate delivery job for each recipient inbox.
      #
      # @param activity [Federails::Activity]
      def enqueue_deliveries(activity)
        inboxes = inboxes_for(activity)
        Federails.logger.debug('Nobody to notice') && return if inboxes.none?

        ActiveJob.perform_all_later(inboxes.map { |url| Federails::NotifyInboxJob.new(activity, url) })
      end

      # Delivers an activity to a single inbox. Called by NotifyInboxJob.
      #
      # @param activity [Federails::Activity]
      # @param inbox_url [String]
      def deliver_to_inbox(activity, inbox_url)
        message = payload(activity)
        validate_message!(activity, message)
        Federails.logger.debug { "Sending activity ##{activity.id} to inbox at #{inbox_url}" }
        resp = post_to_inbox(inbox_url: inbox_url, message: message, from: activity.actor)
        Federails.logger.debug { "#{resp.status}, #{resp.body}" }
      end

      # Posts an activity to its recipients (legacy synchronous delivery).
      #
      # @param activity [Federails::Activity]
      def post_to_inboxes(activity)
        inboxes = inboxes_for(activity)
        Federails.logger.debug('Nobody to notice') && return if inboxes.none?

        message = payload(activity)
        inboxes.each do |url|
          Federails.logger.debug { "Sending activity ##{activity.id} to inbox at #{url}" }
          resp = post_to_inbox(inbox_url: url, message: message, from: activity.actor)
          Federails.logger.debug { "#{resp.status}, #{resp.body}" }
        rescue Federails::PermanentDeliveryError, Federails::TemporaryDeliveryError => e
          Federails.logger.warn { "Delivery failed for #{url}: #{e.message}" }
        end
      end

      #: (Hash[String, untyped], Array[String], ?exclude_actor: String?) -> void
      def forward_activity(payload, collection_urls, exclude_actor: nil)
        inboxes = collection_urls.flat_map do |url|
          collection_to_actors(url).map(&:inbox_url)
        end.compact.uniq

        sender_inbox = actor_inbox_for(exclude_actor)
        inboxes.reject! { |url| url == sender_inbox } if sender_inbox.present?

        sender = forwarding_sender_for(collection_urls)
        message = payload.to_json
        inboxes.each do |url|
          Federails.logger.debug { "Forwarding activity to inbox at #{url}" }
          resp = post_to_inbox(inbox_url: url, message: message, from: sender)
          Federails.logger.debug { "#{resp.status}, #{resp.body}" }
        rescue Federails::PermanentDeliveryError, Federails::TemporaryDeliveryError => e
          Federails.logger.warn { "Forward delivery failed for #{url}: #{e.message}" }
        end
      end

      private

      # Determines the list of inboxes that the activity should be delivered to
      #
      # @return [Array<Federails::Actor>]
      def inboxes_for(activity)
        return [] unless activity.actor.local?

        actor_inbox = activity.actor.inbox_url
        actor_shared_inbox = activity.actor.shared_inbox_url
        addressing = [
          activity.to,
          activity.cc,
          activity.try(:bto),
          activity.try(:bcc),
          activity.try(:audience),
        ].flatten.compact.uniq.reject { |url| url == Fediverse::Collection::PUBLIC }

        # Batch-fetch actors already known in DB to avoid N+1 queries
        known_actors = Federails::Actor.includes(:entity).where(federated_url: addressing).index_by(&:federated_url)

        inboxes = addressing.flat_map do |url|
          actor = known_actors[url] || Federails::Actor.find_or_create_by_federation_url(url)
          [actor.shared_inbox_url.presence || actor.inbox_url]
        rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
          collection_to_actors(url).map { |a| a.shared_inbox_url.presence || a.inbox_url }
        end
        # Filter out actors who have blocked the sender
        blocked_actor_ids = Federails::Block.where(target_actor: activity.actor).select(:actor_id)
        if blocked_actor_ids.exists?
          blocked_actors = Federails::Actor.where(id: blocked_actor_ids)
          blocked_inbox_urls = blocked_actors.flat_map { |a| [a.inbox_url, a.shared_inbox_url] }.compact.to_set
          inboxes.reject! { |url| blocked_inbox_urls.include?(url) }
        end

        excluded = [actor_inbox, actor_shared_inbox].compact
        inboxes.compact.uniq.reject { |url| excluded.include?(url) }
      end

      #: (String, ?max_depth: Integer) -> Array[Federails::Actor]
      def collection_to_actors(url, max_depth: MAX_COLLECTION_DEPTH)
        return [] if max_depth <= 0

        local_actors = actors_for_local_collection(url)
        return local_actors if local_actors

        collection = Collection.fetch(url)
        actor_urls = collection.to_a

        # Batch-fetch actors already known in DB to avoid N+1 queries
        known_actors = Federails::Actor.includes(:entity).where(federated_url: actor_urls).index_by(&:federated_url)

        actor_urls.filter_map do |actor_url|
          known_actors[actor_url] || Federails::Actor.find_or_create_by_federation_url(actor_url)
        rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
          collection_to_actors(actor_url, max_depth: max_depth - 1)
        end
        .flatten
      rescue Errors::NotACollection, URI::InvalidURIError, Federails::Utils::JsonRequest::UnhandledResponseStatus
        []
      end

      #: (String?) -> String?
      def actor_inbox_for(actor_url)
        return if actor_url.blank?

        Federails::Actor.find_or_create_by_federation_url(actor_url).inbox_url
      rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
        nil
      end

      #: (Array[String]) -> Federails::Actor?
      def forwarding_sender_for(collection_urls)
        collection_urls.filter_map do |url|
          route = Federails::Utils::Host.local_route(url)
          next unless route.present? && route[:controller] == 'federails/server/actors' && route[:action] == 'followers'

          Federails::Actor.find_param(route[:id])
        rescue ActiveRecord::RecordNotFound
          nil
        end.first
      end

      #: (Federails::Activity) -> String
      def payload(activity)
        json = Federails::Server::ActivityResource.new(activity).serializable_hash.with_indifferent_access
        json.delete(:bto)
        json.delete(:bcc)
        json.to_json
      end

      #: (inbox_url: String, message: String, ?from: Federails::Actor?) -> untyped
      def post_to_inbox(inbox_url:, message:, from: nil)
        conn = Faraday.default_connection
        resp = conn.builder.build_response(
          conn,
          signed_request(url: inbox_url, message: message, from: from)
        )

        status = resp.status
        return resp if status.between?(200, 299)

        if permanent_delivery_status?(status)
          raise Federails::PermanentDeliveryError.new(
            delivery_error_message(inbox_url: inbox_url, status: status, body: resp.body, retry_after: nil, permanent: true),
            response_code: status, inbox_url: inbox_url
          )
        else
          retry_after = resp.headers['Retry-After'] if status == 429
          raise Federails::TemporaryDeliveryError.new(
            delivery_error_message(inbox_url: inbox_url, status: status, body: resp.body, retry_after: retry_after, permanent: false),
            response_code: status, inbox_url: inbox_url, retry_after: retry_after&.to_i
          )
        end
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::SSLError => e
        raise Federails::TemporaryDeliveryError.new(
          "Delivery to #{inbox_url} failed: #{e.class} #{e.message}",
          response_code: nil, inbox_url: inbox_url
        )
      end

      #: (url: String, message: String, from: Federails::Actor?) -> untyped
      def signed_request(url:, message:, from:)
        req = request(url: url, message: message)
        req.headers['Signature'] = Fediverse::Signature.sign(sender: from, request: req) if from
        req
      end

      #: (url: String, message: String) -> untyped
      def request(url:, message:)
        Faraday.default_connection.build_request(:post) do |req|
          req.url url
          req.body = message
          req.headers['Content-Type'] = Mime[:activitypub].to_s
          req.headers['Accept'] = Mime[:activitypub].to_s
          req.headers['Host'] = URI.parse(url).host
          req.headers['Date'] = Time.now.utc.httpdate
          req.headers['Digest'] = digest(message)
        end
      end

      #: (String) -> String
      def digest(message)
        "SHA-256=#{Base64.strict_encode64(
          OpenSSL::Digest.new('SHA256').digest(message)
        )}"
      end

      #: (Integer) -> bool
      def permanent_delivery_status?(status)
        PERMANENT_DELIVERY_STATUS_CODES.include?(status) && status != 429
      end

      #: (inbox_url: String, status: Integer, body: untyped, retry_after: String?, permanent: bool) -> String
      def delivery_error_message(inbox_url:, status:, body:, retry_after:, permanent:)
        message = "Delivery to #{inbox_url} failed"
        message += ' permanently' if permanent
        message += ": HTTP #{status}"
        message += " (Retry-After: #{retry_after})" if retry_after.present?

        body_excerpt = body.to_s.strip
        return message if body_excerpt.blank?

        message + " - #{body_excerpt.tr("\n", ' ')[0, 300]}"
      end

      #: (Federails::Activity, Hash[Symbol, untyped]) -> void
      def validate_payload!(activity, json)
        return unless activity.action.in?(ACTIONS_REQUIRING_OBJECT)
        return unless json[:object].nil? || update_object_id_missing?(json)

        raise Federails::InvalidDeliveryPayloadError.new(
          invalid_payload_message(activity, json),
          response_code: nil,
          inbox_url:     nil
        )
      end

      #: (Hash[Symbol, untyped]) -> bool
      def update_object_id_missing?(json)
        json[:type] == 'Update' && json[:object].is_a?(Hash) && json[:object][:id].blank?
      end

      #: (Federails::Activity, Hash[Symbol, untyped]) -> String
      def invalid_payload_message(activity, json)
        object_state = if json[:object].nil?
                         'missing object'
                       elsif update_object_id_missing?(json)
                         'missing object.id for Update'
                       else
                         'invalid object'
                       end

        entity_type = activity.respond_to?(:entity_type) ? activity.entity_type : activity.entity&.class&.name
        entity_id = activity.respond_to?(:entity_id) ? activity.entity_id : activity.entity&.try(:id)

        "Refusing to deliver invalid ActivityPub payload for activity ##{activity.id} " \
          "(#{activity.action}, entity_type=#{entity_type.inspect}, entity_id=#{entity_id.inspect}): #{object_state}"
      end

      #: (Federails::Activity, String) -> void
      def validate_message!(activity, message)
        validate_payload!(activity, JSON.parse(message).with_indifferent_access)
      end

      #: (String) -> Array[Federails::Actor]?
      def actors_for_local_collection(url)
        route = Federails::Utils::Host.local_route(url)
        return unless route.present? && route[:controller] == 'federails/server/actors'

        actor = Federails::Actor.find_param(route[:id])
        followings = case route[:action]
                     when 'followers'
                       actor.following_followers.includes(:actor)
                     when 'following'
                       actor.following_follows.includes(:target_actor)
                     else
                       return
                     end

        followings.filter_map do |following|
          target_actor = route[:action] == 'followers' ? following.actor : following.target_actor
          next if target_actor.local?

          target_actor
        end
      rescue ActiveRecord::RecordNotFound
        []
      end
    end
  end
end
