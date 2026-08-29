# typed: true
# rbs_inline: enabled

require 'fedipub/utils/context'

module Fedipub
  module DataTransformer
    module Note
      # Renders a Note. The entity is used to determine actor and generic fields data
      #
      # @param entity [#federail_actor, #federated_url, #created_at, #updated_at] A model instance
      # @param content [String] Note content
      # @param name [String, nil] Optional name/title
      # @param custom [Hash] Optional additional keys (e.g.: attachment, icon, ...). Defaults will override these.
      # @param to [Array<String>, nil] Recipients for the object itself. Defaults to the public collection.
      # @param cc [Array<String>, nil] Copied recipients for the object itself. Defaults to the actor's followers.
      #
      #   Objects must carry their own addressing: some implementations (e.g. Hollo/Fedify)
      #   derive object visibility from the object's to/cc only, and treat an unaddressed
      #   object as a direct message, hiding it from profiles and searches.
      #
      # @return [Hash]
      #
      # @example
      #   Fedipub::DataTransformer::Note.to_federation(comment, content: comment.content, custom: { 'inReplyTo' => comment.parent.federated_url })
      #
      # See:
      #   - https://www.w3.org/TR/activitystreams-vocabulary/#dfn-object
      #   - https://www.w3.org/TR/activitystreams-vocabulary/#dfn-note
      def self.to_federation(entity, content:, name: nil, custom: {}, to: nil, cc: nil)
        # Merge default and custom contexts
        context = Utils::Context.generate(additional: custom.delete('@context'))
        # Merge in standard Note fields
        custom.merge '@context'     => context,
                     'id'           => entity.federated_url,
                     'type'         => 'Note',
                     'name'         => name,
                     'content'      => content,
                     'attributedTo' => entity.fedipub_actor.federated_url,
                     'published'    => entity.created_at,
                     'updated'      => entity.updated_at,
                     'to'           => to || [Fediverse::Collection::PUBLIC],
                     'cc'           => cc || [entity.fedipub_actor.followers_url]
      end
    end
  end
end
