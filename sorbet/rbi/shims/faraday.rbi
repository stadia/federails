# typed: true

# Faraday exposes the verb helpers of its default connection as singleton
# methods through `Forwardable`, which Sorbet/Tapioca cannot see.
module Faraday
  class << self
    def delete(url = nil, params = nil, headers = nil, &block); end
    def get(url = nil, params = nil, headers = nil, &block); end
    def head(url = nil, params = nil, headers = nil, &block); end
    def options(url = nil, params = nil, headers = nil, &block); end
    def patch(url = nil, body = nil, headers = nil, &block); end
    def post(url = nil, body = nil, headers = nil, &block); end
    def put(url = nil, body = nil, headers = nil, &block); end
  end
end
