# rbs_inline: enabled

module Fediverse
  class Collection < Array #[untyped]
    PUBLIC = 'https://www.w3.org/ns/activitystreams#Public'.freeze #: String
    DEFAULT_MAX_PAGES = 100 #: Integer

    attr_reader :total_items #: Integer?
    attr_reader :id #: String?
    attr_reader :type #: String?

    #: (String, ?max_pages: Integer) -> Fediverse::Collection
    def self.fetch(url, max_pages: DEFAULT_MAX_PAGES)
      new.fetch(url, max_pages: max_pages)
    end

    #: (String, ?max_pages: Integer) -> self
    def fetch(url, max_pages: DEFAULT_MAX_PAGES)
      json = Fediverse::Request.dereference(url)
      @total_items = json['totalItems']
      @id = json['id']
      @type = json['type']
      raise Errors::NotACollection unless %w[OrderedCollection Collection].include?(@type)

      next_url = json['first']
      pages_fetched = 0
      while next_url && pages_fetched < max_pages
        page = Fediverse::Request.dereference(next_url)
        concat(page['orderedItems'] || page['items'])
        next_url = page['next']
        pages_fetched += 1
      end
      self
    end
  end

  module Errors
    class NotACollection < StandardError; end
  end
end
