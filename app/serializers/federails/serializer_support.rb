module Federails
  module SerializerSupport
    extend self

    def json_ld_context(additional: nil)
      Federails::Utils::Context.generate(additional: additional)
    end

    def route_helpers
      Federails::Engine.routes.url_helpers
    end
  end
end
