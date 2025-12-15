class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # Reset Current attributes at the start and end of each job to prevent cache bleed
  # between jobs in the same worker process/thread
  around_perform do |job, block|
    Current.reset
    block.call
  ensure
    Current.reset
  end
end
