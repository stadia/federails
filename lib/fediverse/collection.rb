module Fediverse
  class Collection < Array
    PUBLIC = 'https://www.w3.org/ns/activitystreams#Public'.freeze

    attr_reader :total_items, :id, :type

    def self.fetch(url)
      new.fetch(url)
    end

    def fetch(url)
      json = Fediverse::Request.dereference(url)
      @total_items = json['totalItems']
      @id = json['id']
      @type = json['type']
      raise Errors::NotACollection unless %w[OrderedCollection Collection].include?(@type)

      next_url = json['first']
      while next_url
        page = Fediverse::Request.dereference(next_url)
        concat(page['orderedItems'] || page['items'])
        next_url = page['next']
      end
      self
    end
  end

  module Errors
    class NotACollection < StandardError; end
  end
end
