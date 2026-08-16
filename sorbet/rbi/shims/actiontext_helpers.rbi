# typed: true
# frozen_string_literal: true

# ActionText helper modules live in the engine's `app/helpers` directory, so they
# are autoloaded by Rails at runtime and cannot be captured by `tapioca gems`.
# These shims only exist so that generated DSL RBIs (helper proxies) resolve.
module ActionText
  module ContentHelper; end
  module TagHelper; end
end
