require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_many(:campaigns).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_presence_of(:password) }
  end

  describe 'Devise configuration' do
    it 'should be database authenticatable' do
      expect(User.devise_modules).to include(:database_authenticatable)
    end

    it 'should be registerable' do
      expect(User.devise_modules).to include(:registerable)
    end

    it 'should be recoverable' do
      expect(User.devise_modules).to include(:recoverable)
    end

    it 'should be rememberable' do
      expect(User.devise_modules).to include(:rememberable)
    end

    it 'should be validatable' do
      expect(User.devise_modules).to include(:validatable)
    end
  end

  describe 'creation' do
    it 'creates a valid user' do
      user = build(:user)
      expect(user).to be_valid
      expect(user.save).to be true
    end

    it 'requires email' do
      user = build(:user, email: nil)
      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
    end

    it 'requires password' do
      user = build(:user, password: nil)
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it 'requires password confirmation' do
      user = build(:user, password: 'password123', password_confirmation: 'different')
      expect(user).not_to be_valid
      expect(user.errors[:password_confirmation]).to be_present
    end

    it 'requires valid email format' do
      user = build(:user, email: 'invalid-email')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
    end

    it 'requires unique email' do
      create(:user, email: 'test@example.com')
      duplicate_user = build(:user, email: 'test@example.com')
      expect(duplicate_user).not_to be_valid
      expect(duplicate_user.errors[:email]).to be_present
    end

    it 'is case-insensitive for email uniqueness' do
      create(:user, email: 'test@example.com')
      duplicate_user = build(:user, email: 'TEST@EXAMPLE.COM')
      expect(duplicate_user).not_to be_valid
      expect(duplicate_user.errors[:email]).to be_present
    end
  end

  describe 'campaigns association' do
    let(:user) { create(:user) }

    it 'can have multiple campaigns' do
      campaign1 = create(:campaign, user: user)
      campaign2 = create(:campaign, user: user)

      expect(user.campaigns.count).to eq(2)
      expect(user.campaigns).to include(campaign1, campaign2)
    end

    it 'destroys associated campaigns when user is destroyed' do
      campaign = create(:campaign, user: user)
      user_id = user.id
      campaign_id = campaign.id

      user.destroy

      expect(Campaign.find_by(id: campaign_id)).to be_nil
      expect(User.find_by(id: user_id)).to be_nil
    end
  end

  describe '.from_google_omniauth' do
    let(:auth) do
      double('Auth',
        provider: 'google_oauth2',
        uid: '12345',
        info: double('Info',
          email: 'oauth@example.com',
          first_name: 'OAuthFirst',
          last_name: 'OAuthLast',
          name: 'OAuthFullName',
          present?: true
        )
      )
    end

    it 'returns user if provider/uid match exists' do
      user = create(:user, provider: 'google_oauth2', uid: '12345')
      expect(User.from_google_omniauth(auth)).to eq(user)
    end

    it 'finds or initializes by email if no provider/uid match' do
      user = User.from_google_omniauth(auth)
      expect(user.email).to eq('oauth@example.com')
      expect(user.provider).to eq('google_oauth2')
      expect(user.uid).to eq('12345')
      expect(user.password).to be_present
      expect(user).to be_persisted
    end

    it 'sets first_name and last_name from auth.info' do
      user = User.from_google_omniauth(auth)
      expect(user.first_name).to eq('OAuthFirst')
      expect(user.last_name).to eq('OAuthLast')
    end

    it 'splits name if first_name not present' do
      allow(auth.info).to receive(:first_name).and_return(nil)
      allow(auth.info).to receive(:name).and_return('Split Name')
      user = User.from_google_omniauth(auth)
      expect(user.first_name).to eq('Split')
      expect(user.last_name).to eq('Name')
    end

    it 'sets last_name from auth.info.last_name if present' do
      allow(auth.info).to receive(:first_name).and_return(nil)
      allow(auth.info).to receive(:name).and_return('OnlyFirst')
      allow(auth.info).to receive(:last_name).and_return('Lasty')
      user = User.from_google_omniauth(auth)
      expect(user.last_name).to eq('Lasty')
    end
  end

  describe '#profile_complete?' do
    it 'returns true if workspace_name and job_title are present' do
      user = build(:user, workspace_name: 'Workspace', job_title: 'Title')
      expect(user.profile_complete?).to be true
    end

    it 'returns false if workspace_name is missing' do
      user = build(:user, workspace_name: nil, job_title: 'Title')
      expect(user.profile_complete?).to be false
    end

    it 'returns false if job_title is missing' do
      user = build(:user, workspace_name: 'Workspace', job_title: nil)
      expect(user.profile_complete?).to be false
    end
  end

  describe '#gmail_connected?' do
    it 'returns true if gmail_refresh_token is present' do
      user = build(:user, gmail_refresh_token: 'token')
      expect(user.gmail_connected?).to be true
    end

    it 'returns false if gmail_refresh_token is nil' do
      user = build(:user, gmail_refresh_token: nil)
      expect(user.gmail_connected?).to be false
    end
  end

  describe '#gmail_token_expired?' do
    it 'returns true if gmail_token_expires_at is in the past' do
      user = build(:user, gmail_token_expires_at: 1.hour.ago)
      expect(user.gmail_token_expired?).to be true
    end

    it 'returns false if gmail_token_expires_at is in the future' do
      user = build(:user, gmail_token_expires_at: 1.hour.from_now)
      expect(user.gmail_token_expired?).to be false
    end

    it 'returns false if gmail_token_expires_at is nil' do
      user = build(:user, gmail_token_expires_at: nil)
      expect(user.gmail_token_expired?).to be false
    end
  end

  describe '#can_send_gmail?' do
    it 'returns true if gmail_access_token and gmail_email are present' do
      user = build(:user, gmail_access_token: 'token', gmail_email: 'email@example.com')
      expect(user.can_send_gmail?).to be true
    end

    it 'returns false if gmail_access_token is missing' do
      user = build(:user, gmail_access_token: nil, gmail_email: 'email@example.com')
      expect(user.can_send_gmail?).to be false
    end

    it 'returns false if gmail_email is missing' do
      user = build(:user, gmail_access_token: 'token', gmail_email: nil)
      expect(user.can_send_gmail?).to be false
    end
  end

  describe '#send_gmail!' do
    let(:user) { build(:user, gmail_access_token: 'token', gmail_email: 'email@example.com') }

    it 'raises error if cannot send gmail' do
      user.gmail_access_token = nil
      expect { user.send_gmail!(to: 'to@example.com', subject: 'Subject', text_body: 'Body') }
        .to raise_error('User has not connected Gmail')
    end

    it 'calls GmailSender.send_email if can send gmail' do
      expect(GmailSender).to receive(:send_email).with(
        user: user,
        to: 'to@example.com',
        subject: 'Subject',
        text_body: 'Body',
        html_body: nil
      )
      user.send_gmail!(to: 'to@example.com', subject: 'Subject', text_body: 'Body')
    end
  end
end
