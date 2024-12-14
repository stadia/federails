module Jekyll
  # Adds all pages of "/reference" in a Jekyll collection and adds metadata
  #
  # `sleeping_king_studios-yard` generates markdown in `/references`. This is nice but all the files are now part of the
  # "root" documents. As it fits nicely with Just-the-docs, grouping these pages in a Jekyll collection is nicer.
  class CodeReferenceMetas < Generator
    safe true
    priority :lowest # Ensure other plugins are loaded before this one

    # Collection name as referenced in _config.yml
    COLLECTION_NAME = 'code_reference'.freeze

    def generate(site)
      # Create a virtual collection
      collection = Collection.new site, COLLECTION_NAME

      site.pages.each do |page|
        next unless reference_page? page
        next if CodeReferenceMetas.ignore_path? page.path

        add_metas(page)

        # Add to collection
        collection.docs << page
      end

      # Remove all references from site pages
      site.pages.reject! { |page| reference_page? page }

      # Add the virtual collection
      site.collections[COLLECTION_NAME] = collection
    end

    def self.ignore_path?(path)
      return false unless path

      path.match?(%r{federails/(client|server|application-).*(controller|policy|policy/scope|job|mailer|record)(.md)?$}) ||
        path.match?(%r{federails/[^/]+(generator|policy|job)(.md)?$}) ||
        path.match?(%r{federails/(engine|server|client)(.md)?$})
    end

    private

    def reference_page?(page)
      page.path.start_with?('reference/')
    end

    def add_metas(page)
      title, parent = title_and_parent(page.path)

      # Add metas
      page.data['title'] ||= title
      page.data['parent'] = parent if parent
    end

    def title_and_parent(path)
      chunks = path.split('/')
      chunks[chunks.size - 1] = File.basename(chunks.last, '.md')
      chunks.shift
      chunks.map! { |c| c.split('-').map(&:capitalize).join }

      title = chunks.join('::')
      chunks.pop
      parent = chunks.join('::')

      [title, parent]
    end
  end
end
