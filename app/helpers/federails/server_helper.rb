require 'federails/utils/context'

module Federails
  module ServerHelper
    def remote_follow_url
      method_name = Federails.configuration.remote_follow_url_method.to_s
      if method_name.starts_with? 'federails.'
        send(method_name.gsub('federails.', ''))
      else
        Rails.application.routes.url_helpers.send(method_name)
      end
    end

    def set_json_ld_context(json, additional: nil)
      json.set! '@context', Federails::Utils::Context.generate(additional: additional)
    end
  end
end
