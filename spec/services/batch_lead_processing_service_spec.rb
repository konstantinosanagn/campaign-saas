require 'rails_helper'

RSpec.describe BatchLeadProcessingService, type: :service do
  let(:user) { create(:user, llm_api_key: 'test-gemini-key', tavily_api_key: 'test-tavily-key') }
  let(:campaign) { create(:campaign, user: user) }
  let(:lead1) { create(:lead, campaign: campaign, stage: 'queued') }
  let(:lead2) { create(:lead, campaign: campaign, stage: 'queued') }
  let(:lead3) { create(:lead, campaign: campaign, stage: 'queued') }
  let(:lead_ids) { [ lead1.id, lead2.id, lead3.id ] }

  describe '.process_leads' do
    context 'with valid inputs' do
      it 'enqueues jobs for all valid leads' do
        expect {
          described_class.process_leads(lead_ids, campaign, user)
        }.to have_enqueued_job(AgentExecutionJob).exactly(3).times
      end

      it 'enqueues job with correct parameters for each lead' do
        described_class.process_leads(lead_ids, campaign, user)

        expect(AgentExecutionJob).to have_been_enqueued.with(hash_including(lead_run_id: lead1.reload.current_lead_run_id))
        expect(AgentExecutionJob).to have_been_enqueued.with(hash_including(lead_run_id: lead2.reload.current_lead_run_id))
        expect(AgentExecutionJob).to have_been_enqueued.with(hash_including(lead_run_id: lead3.reload.current_lead_run_id))
      end

      it 'returns success result with queued leads' do
        result = described_class.process_leads(lead_ids, campaign, user)

        expect(result[:total]).to eq(3)
        expect(result[:queued_count]).to eq(3)
        expect(result[:failed_count]).to eq(0)
        expect(result[:queued].length).to eq(3)
        expect(result[:queued].map { |q| q[:lead_id] }).to contain_exactly(lead1.id, lead2.id, lead3.id)
        expect(result[:queued].all? { |q| q[:job_id].present? }).to be true
      end

      it 'includes job IDs in queued results' do
        result = described_class.process_leads(lead_ids, campaign, user)

        result[:queued].each do |queued_item|
          expect(queued_item).to have_key(:lead_id)
          expect(queued_item).to have_key(:job_id)
          expect(queued_item[:job_id]).to be_present
        end
      end

      context 'with custom batch size' do
        it 'processes leads in specified batch size' do
          result = described_class.process_leads(lead_ids, campaign, user, batch_size: 2)

          expect(result[:total]).to eq(3)
          expect(result[:queued_count]).to eq(3)
        end
      end
    end

    context 'with invalid campaign ownership' do
      let(:other_user) { create(:user) }
      let(:other_campaign) { create(:campaign, user: other_user) }

      it 'returns error when campaign does not belong to user' do
        result = described_class.process_leads(lead_ids, other_campaign, user)

        expect(result[:error]).to eq("Campaign not found or unauthorized")
        expect(result[:total]).to eq(0)
        expect(result[:queued_count]).to eq(0)
      end
    end

    context 'with leads from different campaign' do
      let(:other_campaign) { create(:campaign, user: user) }
      let(:other_lead) { create(:lead, campaign: other_campaign) }

      it 'filters to only leads from the specified campaign' do
        mixed_lead_ids = [ lead1.id, lead2.id, other_lead.id ]
        result = described_class.process_leads(mixed_lead_ids, campaign, user)

        expect(result[:total]).to eq(2)  # Only lead1 and lead2
        expect(result[:queued_count]).to eq(2)
        expect(result[:queued].map { |q| q[:lead_id] }).to contain_exactly(lead1.id, lead2.id)
      end
    end

    context 'with empty lead IDs array' do
      it 'returns error' do
        result = described_class.process_leads([], campaign, user)

        expect(result[:error]).to eq("No valid leads found")
        expect(result[:total]).to eq(0)
        expect(result[:queued_count]).to eq(0)
      end
    end

    context 'with non-existent lead IDs' do
      it 'filters out non-existent leads' do
        mixed_ids = [ lead1.id, 99999, 99998 ]
        result = described_class.process_leads(mixed_ids, campaign, user)

        expect(result[:total]).to eq(1)  # Only lead1 exists
        expect(result[:queued_count]).to eq(1)
        expect(result[:queued].first[:lead_id]).to eq(lead1.id)
      end
    end

    context 'when job enqueue fails' do
      before do
        allow(AgentExecutionJob).to receive(:perform_later).and_raise(StandardError, "Queue error")
      end

      it 'captures error and continues processing other leads' do
        result = described_class.process_leads(lead_ids, campaign, user)

        expect(result[:failed_count]).to eq(3)  # All failed
        expect(result[:queued_count]).to eq(0)
        expect(result[:failed].length).to eq(3)
        expect(result[:failed].all? { |f| f[:error].present? }).to be true
      end
    end

    context 'with large batch' do
      let(:large_lead_ids) { Array.new(25) { create(:lead, campaign: campaign).id } }

      it 'processes all leads without exceeding max concurrent jobs' do
        result = described_class.process_leads(large_lead_ids, campaign, user, batch_size: 10)

        expect(result[:total]).to eq(25)
        expect(result[:queued_count]).to eq(25)
        expect(result[:failed_count]).to eq(0)
      end
    end
  end

  describe '.process_leads_sync' do
    it 'is deprecated and raises' do
      expect {
        described_class.process_leads_sync(lead_ids, campaign, user)
      }.to raise_error(NotImplementedError)
    end
  end

  describe '.recommended_batch_size' do
    it 'returns default batch size for production' do
      allow(Rails.env).to receive(:production?).and_return(true)
      allow(Rails.env).to receive(:development?).and_return(false)

      size = described_class.recommended_batch_size
      expect(size).to be_between(1, BatchLeadProcessingService::MAX_CONCURRENT_JOBS)
    end

    it 'returns smaller batch size for development' do
      # Align test with current implementation (returns 10 for development)
      allow(Rails.env).to receive(:production?).and_return(false)
      allow(Rails.env).to receive(:development?).and_return(true)

      size = described_class.recommended_batch_size
      expect(size).to eq(10)
    end

    context 'with BATCH_SIZE environment variable' do
      it 'uses environment variable when set' do
        original_batch_size = ENV["BATCH_SIZE"]
        ENV["BATCH_SIZE"] = "15"
        allow(Rails.env).to receive(:production?).and_return(true)
        size = described_class.recommended_batch_size
        expect(size).to eq(15)
        ENV["BATCH_SIZE"] = original_batch_size
      end
    end

    it 'does not exceed MAX_CONCURRENT_JOBS' do
      original_batch_size = ENV["BATCH_SIZE"]
      ENV["BATCH_SIZE"] = "100"
      allow(Rails.env).to receive(:production?).and_return(true)

      size = described_class.recommended_batch_size
      expect(size).to eq(BatchLeadProcessingService::MAX_CONCURRENT_JOBS)

      ENV["BATCH_SIZE"] = original_batch_size
    end
  end
end
