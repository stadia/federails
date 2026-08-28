# rbs_inline: enabled

require 'fedipub/utils/context'

module Fedipub
  module ServerHelper
    def remote_follow_url
      method_name = Fedipub.configuration.remote_follow_url_method.to_s
      if method_name.starts_with? 'fedipub.'
        send(method_name.gsub('fedipub.', ''))
      else
        Rails.application.routes.url_helpers.send(method_name)
      end
    end

    def set_json_ld_context(json, additional: nil)
      json.set! '@context', Fedipub::Utils::Context.generate(additional: additional)
    end
  end
end
