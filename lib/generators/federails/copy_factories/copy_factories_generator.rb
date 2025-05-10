module Federails
  class CopyFactoriesGenerator < Rails::Generators::Base
    SOURCE_DIRECTORY = File.expand_path('../../../../spec/factories/federails', __dir__)

    source_root SOURCE_DIRECTORY

    def copy_factories
      dest = Rails.root.join('spec', 'factories')

      Dir.entries(SOURCE_DIRECTORY)
         .each do |node|
        source_path = File.join(SOURCE_DIRECTORY, node)
        next unless File.file?(source_path) && node.match?(/\.rb\Z/)

        file_path = File.join(dest, "federails_#{node}")
        copy_file node, file_path
        gsub_file file_path, /(FactoryBot.define do\n\s+factory) :(\w+),/, '\1 :federails_\2,'
      end
    end
  end
end
