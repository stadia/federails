module Federails
  class ApplicationJob < ActiveJob::Base
    queue_as { Configuration.job_queue.to_sym }

    discard_on ActiveJob::DeserializationError
    after_discard do |_job, exception|
      Federails.logger.info exception.to_s
    end
  end
end
