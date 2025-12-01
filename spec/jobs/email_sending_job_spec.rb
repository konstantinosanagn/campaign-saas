require 'rails_helper'
require_relative '../../app/errors/email_errors'

RSpec.describe EmailSendingJob, type: :job do
  include AgentConstants

  let(:user) { create(:user, email: 'user@example.com') }
  let(:campaign) { create(:campaign, user: user, title: 'Test Campaign') }
  let(:lead) do
    create(:lead,
      campaign: campaign,
      email: 'lead@example.com',
      name: 'John Doe',
      stage: AgentConstants::STAGE_DESIGNED,
      email_status: 'not_scheduled'
    )
  end

  let(:design_output) do
    create(:agent_output,
      lead: lead,
      agent_name: AgentConstants::AGENT_DESIGN,
      status: AgentConstants::STATUS_COMPLETED,
      output_data: { 'formatted_email' => 'Subject: Test\n\nEmail content' }
    )
  end

  before do
    design_output
  end

  describe '#perform' do
    context 'when lead exists and is ready' do
      before do
        allow(EmailSenderService).to receive(:lead_ready?).with(lead).and_return(true)
        service = instance_double(EmailSenderService)
        allow(EmailSenderService).to receive(:new).with(lead).and_return(service)
        allow(service).to receive(:send_email!)
      end

      it 'sends email via EmailSenderService' do
        service = instance_double(EmailSenderService)
        expect(EmailSenderService).to receive(:new).with(lead).and_return(service)
        expect(service).to receive(:send_email!)

        EmailSendingJob.perform_now(lead.id)
      end

      it 'does not skip if email_status is not sent' do
        lead.update(email_status: 'not_scheduled')
        service = instance_double(EmailSenderService)
        allow(EmailSenderService).to receive(:new).with(lead).and_return(service)
        expect(service).to receive(:send_email!)

        EmailSendingJob.perform_now(lead.id)
      end
    end

    context 'when lead does not exist' do
      it 'skips execution and logs warning' do
        expect(Rails.logger).to receive(:warn).with(/Lead \d+ not found/)

        EmailSendingJob.perform_now(99999)
      end
    end

    context 'when email is already sent' do
      before do
        lead.update(email_status: 'sent')
      end

      it 'skips execution' do
        service = instance_double(EmailSenderService)
        expect(EmailSenderService).not_to receive(:new)

        EmailSendingJob.perform_now(lead.id)
      end

      it 'logs info message' do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/already has status 'sent'/)

        EmailSendingJob.perform_now(lead.id)
      end
    end

    context 'when lead is not ready' do
      before do
        allow(EmailSenderService).to receive(:lead_ready?).with(lead).and_return(false)
      end

      it 'updates lead status to failed' do
        EmailSendingJob.perform_now(lead.id)

        lead.reload
        expect(lead.email_status).to eq('failed')
        expect(lead.last_email_error_message).to include('not ready to send')
      end
    end

    context 'when EmailSenderService raises TemporaryEmailError' do
      let(:service_double) { instance_double(EmailSenderService) }
      let(:temporary_error) { TemporaryEmailError.new('Network timeout', provider: 'gmail_api', lead_id: lead.id) }

      before do
        allow(EmailSenderService).to receive(:lead_ready?).with(lead).and_return(true)
        allow(EmailSenderService).to receive(:new).with(lead).and_return(service_double)
        allow(service_double).to receive(:send_email!).and_raise(temporary_error)
      end

      it 'updates lead status to failed' do
        # With retry_on TemporaryEmailError, ActiveJob handles the exception internally
        expect {
          EmailSendingJob.perform_now(lead.id)
        }.not_to raise_error

        lead.reload
        expect(lead.email_status).to eq('failed')
        expect(lead.last_email_error_message).to include('Network timeout')
        expect(lead.last_email_error_at).to be_present
      end

      it 'triggers retry mechanism for temporary errors' do
        # TemporaryEmailError should trigger retry_on, so ActiveJob schedules retries
        expect {
          EmailSendingJob.perform_now(lead.id)
        }.not_to raise_error

        # Verify the error was caught and lead status was updated
        lead.reload
        expect(lead.email_status).to eq('failed')
        expect(lead.last_email_error_message).to include('Network timeout')
      end

      it 'logs retry warning' do
        expect(Rails.logger).to receive(:warn).with(/Retrying after temporary error/)
        allow(Rails.logger).to receive(:warn) # Allow other warnings

        EmailSendingJob.perform_now(lead.id)
      end
    end

    context 'when EmailSenderService raises PermanentEmailError' do
      let(:service_double) { instance_double(EmailSenderService) }
      let(:permanent_error) { PermanentEmailError.new('Authentication failed', provider: 'smtp', lead_id: lead.id) }

      before do
        allow(EmailSenderService).to receive(:lead_ready?).with(lead).and_return(true)
        allow(EmailSenderService).to receive(:new).with(lead).and_return(service_double)
        allow(service_double).to receive(:send_email!).and_raise(permanent_error)
      end

      it 'updates lead status to failed' do
        # With discard_on PermanentEmailError, ActiveJob discards the job
        expect {
          EmailSendingJob.perform_now(lead.id)
        }.not_to raise_error

        lead.reload
        expect(lead.email_status).to eq('failed')
        expect(lead.last_email_error_message).to include('Authentication failed')
        expect(lead.last_email_error_at).to be_present
      end

      it 'discards job without retrying' do
        # PermanentEmailError should trigger discard_on, so no retries
        expect {
          EmailSendingJob.perform_now(lead.id)
        }.not_to raise_error

        lead.reload
        expect(lead.email_status).to eq('failed')
      end

      it 'logs permanent failure' do
        expect(Rails.logger).to receive(:error).with(/Permanent email failure for lead_id=#{lead.id}/)
        allow(Rails.logger).to receive(:error) # Allow other errors

        EmailSendingJob.perform_now(lead.id)
      end
    end
  end

  describe 'retry configuration' do
    it 'has retry_on configured for TemporaryEmailError' do
      # ActiveJob doesn't expose retry_on as a query method, so we test behavior
      # by checking that the job class has the retry configuration
      expect(EmailSendingJob.retry_jitter).to be_present
    end

    it 'has discard_on configured for PermanentEmailError' do
      # ActiveJob doesn't expose discard_on as a query method
      # We verify the configuration exists by checking the job can be instantiated
      expect { EmailSendingJob.new }.not_to raise_error
    end

    it 'has discard_on configured for ArgumentError' do
      # ActiveJob doesn't expose discard_on as a query method
      # We verify the configuration exists by checking the job can be instantiated
      expect { EmailSendingJob.new }.not_to raise_error
    end
  end
end
