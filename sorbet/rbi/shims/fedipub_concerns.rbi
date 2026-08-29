# typed: true

# `Fedipub::DataEntity` is only ever mixed into `ActiveRecord::Base` subclasses,
# but that contract cannot be declared in the source: the gem does not depend on
# `sorbet-runtime` at runtime, so `extend T::Helpers` is not available there.
# Declaring it here keeps `srb tc` aware of the inherited Active Record API
# (`persisted?`, `save!`, …) without adding a runtime dependency.
module Fedipub::DataEntity
  requires_ancestor { ActiveRecord::Base }
end
