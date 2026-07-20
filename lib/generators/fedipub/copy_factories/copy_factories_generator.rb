module Federails
  class CopyFactoriesGenerator < Rails::Generators::Base
    SOURCE_DIRECTORY = File.expand_path('../../../../spec/factories/federails', __dir__)
    FACTORY_DEFINITION_REGEX = /(FactoryBot.define do\n\s+factory) :(\w+),/

    source_root SOURCE_DIRECTORY

    def initialize
      super
      @files = []
      @factories = []
    end

    def copy_factories
      dest = Rails.root.join('spec', 'factories')

      Dir.entries(SOURCE_DIRECTORY).each do |node|
        source_path = File.join(SOURCE_DIRECTORY, node)
        next unless File.file?(source_path) && node.match?(/\.rb\Z/)

        file_path = File.join(dest, "federails_#{node}")
        copy_file node, file_path
        @files << file_path
        @factories << File.read(file_path).match(FACTORY_DEFINITION_REGEX)&.[](2)
      end

      substitute_values!
    end

    private

    def substitute_values!
      @factories.compact!
      @files.each do |file|
        gsub_file file, FACTORY_DEFINITION_REGEX, '\1 :federails_\2,'

        @factories.each do |factory|
          gsub_file file, ":#{factory}", ":federails_#{factory}"
        end
      end
    end
  end
end
