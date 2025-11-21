RSpec.configure do |config|
  config.include ActiveJob::TestHelper

  config.after do
    clear_enqueued_jobs
  end
end
