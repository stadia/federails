module Fedipub
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path('templates', __dir__)

    def copy_files
      copy_file 'fedipub.yml', Rails.root.join('config', 'fedipub.yml')
      copy_file 'fedipub.rb', Rails.root.join('config', 'initializers', 'fedipub.rb')
    end
  end
end
