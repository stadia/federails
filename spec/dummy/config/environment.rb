# Load the Rails application.
require_relative 'application'

# Initialize the Rails application.
Rails.application.initialize!

# Load engine factories
FactoryBot.definition_file_paths = FactoryBot.definition_file_paths.dup << Fedipub::Engine.root.join('spec', 'factories')
FactoryBot.reload
