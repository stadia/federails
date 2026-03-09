require_relative 'lib/federails/version'

Gem::Specification.new do |spec|
  spec.required_ruby_version = '>= 3.1.2'
  spec.name        = 'federails'
  spec.version     = Federails::VERSION
  spec.authors     = ['Manuel Tancoigne']
  spec.email       = ['manu@experimentslabs.com']
  spec.homepage    = 'https://experimentslabs.com'
  spec.summary     = 'An ActivityPub engine for Ruby on Rails'
  spec.description = spec.summary
  spec.license     = 'MIT'

  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://gitlab.com/experimentslabs/federails/'
  spec.metadata['changelog_uri'] = 'https://gitlab.com/experimentslabs/federails/-/blob/main/CHANGELOG.md'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'LICENSE', 'Rakefile', 'README.md']
  end

  spec.add_dependency 'faraday'
  spec.add_dependency 'faraday-follow_redirects'
  spec.add_dependency 'jbuilder', '~> 2.7'
  spec.add_dependency 'json-ld', '>= 3.2.0'
  spec.add_dependency 'json-ld-preloaded', '>= 3.2.0'
  spec.add_dependency 'kaminari', '>= 1.2.0'
  spec.add_dependency 'ostruct'
  spec.add_dependency 'pundit', '>= 2.3.0'
  spec.add_dependency 'rails', '>= 7.0.4'
end
