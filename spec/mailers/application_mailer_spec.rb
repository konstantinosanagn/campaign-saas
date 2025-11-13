require 'rails_helper'

RSpec.describe ApplicationMailer, type: :mailer do
  describe 'default configuration' do
    it 'has a default from address' do
      expect(described_class.default[:from]).to be_present
    end
  end
end
