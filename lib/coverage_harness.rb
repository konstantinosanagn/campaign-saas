begin
  require "rspec/mocks"
rescue LoadError
  # RSpec is not available in production (test-only dependency).
  # The harness does not depend on it at runtime, so skip the require.
end

module CoverageHarness
  class << self
    def run
      return if @ran

      @ran = true
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          execute_harness
          raise ActiveRecord::Rollback
        end
      end
    rescue => e
      Rails.logger.error("CoverageHarness failed: #{e.class}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise
    end

    private

    def execute_harness
      # Placeholder to be filled with detailed harness steps.
    end
  end
end
