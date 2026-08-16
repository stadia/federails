# typed: true
# frozen_string_literal: true

# Add your extra requires here (`bin/tapioca require` can be used to bootstrap this list)

# federails is a Rails engine: framework pieces must be loaded before the gem is required.
require 'rails'
require 'rails/generators'
require 'active_record'
require 'action_controller'
require 'action_mailer'
require 'active_job'
require 'openssl'
require 'active_storage'
require 'active_support/testing/stream'

# json-ld is autoload-based: touch the constants so RBI generation sees them.
require 'rdf'
require 'json/ld'
JSON::LD.const_get(:API)
JSON::LD.const_get(:Context)
