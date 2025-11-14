require 'rails_helper'

RSpec.describe CampaignMailer, type: :mailer do
  describe '#send_email' do
    let(:to) { 'recipient@example.com' }
    let(:recipient_name) { 'John Doe' }
    let(:email_content) { '<p>Hello, this is a test email.</p>' }
    let(:campaign_title) { 'Test Campaign' }
    let(:from_email) { nil }

    let(:mail) do
      described_class.send_email(
        to: to,
        recipient_name: recipient_name,
        email_content: email_content,
        campaign_title: campaign_title,
        from_email: from_email
      )
    end

    it 'renders the headers' do
      expect(mail.subject).to include('Test Campaign')
      expect(mail.to).to eq([ to ])
    end

    it 'includes recipient name in subject' do
      expect(mail.subject).to include('John Doe')
    end

    it 'renders the body' do
      expect(mail.body.encoded).to include(email_content)
    end

    context 'when from_email is provided' do
      let(:from_email) { 'custom@example.com' }

      it 'uses the custom from email' do
        expect(mail.from).to eq([ from_email ])
      end
    end

    context 'when from_email is nil' do
      it 'uses default from email' do
        expect(mail.from).to eq([ ApplicationMailer.default[:from] ])
      end
    end

    context 'when recipient_name is blank' do
      let(:recipient_name) { '' }

      it 'uses generic subject' do
        expect(mail.subject).to include('Outreach Update')
      end
    end

    context 'when recipient_name is nil' do
      let(:recipient_name) { nil }

      it 'uses generic subject' do
        expect(mail.subject).to include('Outreach Update')
      end
    end

    context 'when campaign_title is blank' do
      let(:campaign_title) { '' }

      it 'uses default campaign title' do
        expect(mail.subject).to include('Campaign Outreach')
      end
    end

    context 'when campaign_title is nil' do
      let(:campaign_title) { nil }

      it 'uses default campaign title' do
        expect(mail.subject).to include('Campaign Outreach')
      end
    end
  end
end
