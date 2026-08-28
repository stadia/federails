# rbs_inline: enabled

module Fedipub
  class CopyClientPoliciesGenerator < Rails::Generators::Base
    source_root File.expand_path('../../../../app/policies/fedipub', __dir__)

    def copy_policies
      directory 'client', Rails.root.join('app', 'policies', 'fedipub', 'client')
    end
  end
end
