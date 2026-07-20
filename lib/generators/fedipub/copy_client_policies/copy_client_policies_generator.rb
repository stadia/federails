module Federails
  class CopyClientPoliciesGenerator < Rails::Generators::Base
    source_root File.expand_path('../../../../app/policies/federails', __dir__)

    def copy_policies
      directory 'client', Rails.root.join('app', 'policies', 'federails', 'client')
    end
  end
end
