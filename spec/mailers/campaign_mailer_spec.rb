require 'rails_helper'

RSpec.describe CampaignMailer, type: :mailer do
  describe '#send_email' do
    let(:recipient_email) { 'recipient@example.com' }
    let(:recipient_name) { 'John Doe' }
    let(:email_content) { 'This is the email content with **markdown** formatting.' }
    let(:campaign_title) { 'Test Campaign' }
    let(:from_email) { 'sender@example.com' }

    context 'with all parameters provided' do
      let(:mail) do
        CampaignMailer.send_email(
          to: recipient_email,
          recipient_name: recipient_name,
          email_content: email_content,
          campaign_title: campaign_title,
          from_email: from_email
        )
      end

      it 'sends email to correct recipient' do
        expect(mail.to).to include(recipient_email)
      end

      it 'uses provided from email' do
        expect(mail.from).to include(from_email)
      end

      it 'includes email content in body' do
        # Email content is HTML encoded, so check the HTML part
        expect(mail.html_part.body.to_s).to include('This is the email content')
      end

      it 'builds subject with campaign title and recipient name' do
        expect(mail.subject).to eq("#{campaign_title} – Outreach for #{recipient_name}")
      end

      it 'sets recipient name in template' do
        # Recipient name is used in subject, not necessarily in body
        expect(mail.subject).to include(recipient_name)
      end

      it 'sets campaign title in template' do
        # Campaign title is used in subject
        expect(mail.subject).to include(campaign_title)
      end
    end

    context 'with default from email' do
      let(:mail) do
        CampaignMailer.send_email(
          to: recipient_email,
          recipient_name: recipient_name,
          email_content: email_content,
          campaign_title: campaign_title,
          from_email: nil
        )
      end

      it 'uses ApplicationMailer default from address' do
        expect(mail.from).to include(ApplicationMailer.default[:from])
      end
    end

    context 'with empty recipient name' do
      let(:mail) do
        CampaignMailer.send_email(
          to: recipient_email,
          recipient_name: '',
          email_content: email_content,
          campaign_title: campaign_title
        )
      end

      it 'builds subject without recipient name' do
        expect(mail.subject).to eq("#{campaign_title} – Outreach Update")
      end
    end

    context 'with nil recipient name' do
      let(:mail) do
        CampaignMailer.send_email(
          to: recipient_email,
          recipient_name: nil,
          email_content: email_content,
          campaign_title: campaign_title
        )
      end

      it 'builds subject without recipient name' do
        expect(mail.subject).to eq("#{campaign_title} – Outreach Update")
      end
    end

    context 'with whitespace-only recipient name' do
      let(:mail) do
        CampaignMailer.send_email(
          to: recipient_email,
          recipient_name: '   ',
          email_content: email_content,
          campaign_title: campaign_title
        )
      end

      it 'builds subject without recipient name' do
        expect(mail.subject).to eq("#{campaign_title} – Outreach Update")
      end
    end

    context 'with nil campaign title' do
      let(:mail) do
        CampaignMailer.send_email(
          to: recipient_email,
          recipient_name: recipient_name,
          email_content: email_content,
          campaign_title: nil
        )
      end

      it 'uses default campaign title in subject' do
        expect(mail.subject).to eq("Campaign Outreach – Outreach for #{recipient_name}")
      end
    end

    context 'with empty campaign title' do
      let(:mail) do
        CampaignMailer.send_email(
          to: recipient_email,
          recipient_name: recipient_name,
          email_content: email_content,
          campaign_title: ''
        )
      end

      it 'uses default campaign title in subject' do
        expect(mail.subject).to eq("Campaign Outreach – Outreach for #{recipient_name}")
      end
    end

    context 'delivery' do
      it 'can be delivered' do
        mail = CampaignMailer.send_email(
          to: recipient_email,
          recipient_name: recipient_name,
          email_content: email_content,
          campaign_title: campaign_title
        )

        expect { mail.deliver_now }.not_to raise_error
      end
    end
  end
end
