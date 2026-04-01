# rbs_inline: enabled

require 'fediverse/signature'

module Fediverse
  class Notifier
    MAX_COLLECTION_DEPTH = 3 #: Integer

    class << self
      # Posts an activity to its recipients
      #
      # @param activity [Federails::Activity]
      def post_to_inboxes(activity)
        # Get the list of actors we need to send the activity to
        inboxes = inboxes_for(activity)
        Federails.logger.debug('Nobody to notice') && return if inboxes.none?

        # Deliver to each inbox
        message = payload(activity)
        inboxes.each do |url|
          Federails.logger.debug { "Sending activity ##{activity.id} to inbox at #{url}" }
          resp = post_to_inbox(inbox_url: url, message: message, from: activity.actor)
          Federails.logger.debug { "#{resp.status}, #{resp.body}" }
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
        json = Federails::Server::ActivityResource.new(activity).serializable_hash
        json.delete(:bto)
        json.delete(:bcc)
        json.to_json
      end

      #: (inbox_url: String, message: String, ?from: Federails::Actor?) -> untyped
      def post_to_inbox(inbox_url:, message:, from: nil)
        conn = Faraday.default_connection
        conn.builder.build_response(
          conn,
          signed_request(url: inbox_url, message: message, from: from)
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
