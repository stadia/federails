module Federails
  class CopyClientViewsGenerator < Rails::Generators::Base
    source_root File.expand_path('../../../../app/views', __dir__)

    def copy_views
      directory 'fedipub/client', Rails.root.join('app', 'views', 'fedipub', 'client')
    end
  end
end
