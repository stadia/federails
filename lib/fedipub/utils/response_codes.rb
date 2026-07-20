module Federails
  module Utils
    module ResponseCodes
      UNPROCESSABLE_CONTENT = if Gem::Version.new(Rack::RELEASE) < Gem::Version.new('3.1')
                                :unprocessable_entity
                              else
                                :unprocessable_content
                              end
    end
  end
end
