require 'rails_helper'

RSpec.describe ApplicationMailer, type: :mailer do
  describe 'class configuration' do
    it 'inherits from ActionMailer::Base' do
      expect(ApplicationMailer.superclass).to eq(ActionMailer::Base)
    end

    it 'has default from address' do
      expect(ApplicationMailer.default[:from]).to eq('campaignsaastester@gmail.com')
    end

    it 'has mailer layout configured' do
      # Check that layout is configured in the source code
      source = File.read(Rails.root.join('app/mailers/application_mailer.rb'))
      expect(source).to include('layout "mailer"')
    end
  end

  describe 'as a base class' do
    let(:test_mailer_class) do
      Class.new(ApplicationMailer) do
        def test_email(user)
          mail(to: user.email, subject: 'Test Email', body: 'Test email body')
        end
      end
    end

    let(:user) { create(:user) }

    it 'can be subclassed' do
      expect(test_mailer_class.superclass).to eq(ApplicationMailer)
    end

    it 'inherits ActionMailer functionality' do
      expect(test_mailer_class.ancestors).to include(ActionMailer::Base)
    end

    it 'uses default from address' do
      mail = test_mailer_class.test_email(user)
      expect(mail.from).to include('campaignsaastester@gmail.com')
    end

    it 'can create mail objects' do
      mail = test_mailer_class.test_email(user)
      expect(mail.to).to include(user.email)
      expect(mail.subject).to eq('Test Email')
    end

    it 'can be delivered without template' do
      # Since we're providing body directly, it should work
      mail = test_mailer_class.test_email(user)
      expect(mail.body.raw_source).to include('Test email body')
    end
  end
end
