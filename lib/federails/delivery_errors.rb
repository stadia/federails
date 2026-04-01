module Federails
  class DeliveryError < StandardError
    attr_reader :response_code, :inbox_url

    def initialize(message, response_code: nil, inbox_url: nil)
      @response_code = response_code
      @inbox_url = inbox_url
      super(message)
    end
  end

  class PermanentDeliveryError < DeliveryError; end

  class TemporaryDeliveryError < DeliveryError
    attr_reader :retry_after

    def initialize(message, response_code: nil, inbox_url: nil, retry_after: nil)
      @retry_after = retry_after
      super(message, response_code: response_code, inbox_url: inbox_url)
    end
  end
end
