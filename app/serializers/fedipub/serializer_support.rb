# rbs_inline: enabled

module Fedipub
  module SerializerSupport
    module_function

    def json_ld_context(additional: nil)
      Fedipub::Utils::Context.generate(additional: additional)
    end

    def route_helpers
      Fedipub::Engine.routes.url_helpers
    end
  end
end
