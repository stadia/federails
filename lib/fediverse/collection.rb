module Fediverse
  class Collection < Array
    PUBLIC = 'https://www.w3.org/ns/activitystreams#Public'.freeze
    DEFAULT_MAX_PAGES = 100

    attr_reader :total_items, :id, :type

    def self.fetch(url, max_pages: DEFAULT_MAX_PAGES)
      new.fetch(url, max_pages: max_pages)
    end

    def fetch(url, max_pages: DEFAULT_MAX_PAGES)
      json = Fediverse::Request.dereference(url)
      @total_items = json['totalItems']
      @id = json['id']
      @type = json['type']
      raise Errors::NotACollection unless %w[OrderedCollection Collection].include?(@type)

      next_url_or_page = json['first']
      pages_fetched = 0
      while next_url_or_page && pages_fetched < max_pages
        page = next_url_or_page.is_a?(Hash) ? next_url_or_page : Fediverse::Request.dereference(next_url_or_page)
        concat(page['orderedItems'] || page['items'] || [])
        next_url_or_page = page['next']
        pages_fetched += 1
      end
      self
    end
  end

  module Errors
    class NotACollection < StandardError; end
  end
end
