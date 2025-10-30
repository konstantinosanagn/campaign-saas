require 'rails_helper'

RSpec.describe ApplicationJob, type: :job do
  describe 'class configuration' do
    it 'inherits from ActiveJob::Base' do
      expect(ApplicationJob.superclass).to eq(ActiveJob::Base)
    end

    it 'has retry_on commented out' do
      # Verify that retry_on is not active (commented out)
      source = File.read(Rails.root.join('app/jobs/application_job.rb'))
      expect(source).to include('# retry_on ActiveRecord::Deadlocked')
      expect(source).not_to match(/^\s*retry_on\s+ActiveRecord::Deadlocked/)
    end

    it 'has discard_on commented out' do
      # Verify that discard_on is not active (commented out)
      source = File.read(Rails.root.join('app/jobs/application_job.rb'))
      expect(source).to include('# discard_on ActiveJob::DeserializationError')
      expect(source).not_to match(/^\s*discard_on\s+ActiveJob::DeserializationError/)
    end
  end

  describe 'as a base class' do
    let(:test_job_class) do
      Class.new(ApplicationJob) do
        def perform(*args)
          # Test job implementation
        end
      end
    end

    it 'can be subclassed' do
      expect(test_job_class.superclass).to eq(ApplicationJob)
    end

    it 'inherits ActiveJob functionality' do
      expect(test_job_class.ancestors).to include(ActiveJob::Base)
    end

    it 'can be instantiated' do
      job = test_job_class.new
      expect(job).to be_a(ActiveJob::Base)
    end

    it 'can be queued' do
      expect {
        test_job_class.perform_later
      }.to have_enqueued_job(test_job_class)
    end
  end
end

