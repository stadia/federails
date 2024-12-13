module Jekyll
  module ReferenceHelpers
    def mute_namespace(input)
      chunks = input.split('::')
      return chunks.first unless chunks.size > 1

      name = chunks.pop
      namespace = chunks.join('::')

      namespace = "<span class=\"text-grey-dk-000\">#{namespace}::</span>" if namespace

      "#{namespace}#{name}"
    end
  end
end

Liquid::Template.register_filter(Jekyll::ReferenceHelpers)
