require_relative '../../lib/fedipub/version'

module Jekyll
  class ProjectVersion < Generator
    safe true

    def generate(site)
      site.data['current_version'] = Federails::VERSION
    end
  end
end
