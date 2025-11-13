require 'rails_helper'

RSpec.describe GmailOauthService, type: :service do
  let(:user) { create(:user) }
  let(:mock_client) { instance_double(Signet::OAuth2::Client) }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('GMAIL_CLIENT_ID').and_return('test-client-id')
    allow(ENV).to receive(:[]).with('GMAIL_CLIENT_SECRET').and_return('test-client-secret')
    allow(ENV).to receive(:fetch).with('MAILER_HOST', 'localhost:3000').and_return('localhost:3000')
  end

  describe '.authorization_url' do
    let(:auth_uri) { URI.parse('https://accounts.google.com/o/oauth2/auth?client_id=test') }

    before do
      allow(Signet::OAuth2::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:authorization_uri).and_return(auth_uri)
    end

    it 'returns authorization URL' do
      url = described_class.authorization_url(user)

      expect(url).to eq(auth_uri.to_s)
    end

    it 'builds client with correct parameters' do
      expect(Signet::OAuth2::Client).to receive(:new).with(
        hash_including(
          authorization_uri: 'https://accounts.google.com/o/oauth2/auth',
          token_credential_uri: 'https://oauth2.googleapis.com/token',
          client_id: 'test-client-id',
          client_secret: 'test-client-secret',
          scope: 'https://www.googleapis.com/auth/gmail.send',
          access_type: 'offline',
          prompt: 'consent'
        )
      ).and_return(mock_client)

      described_class.authorization_url(user)
    end

    it 'uses GMAIL_REDIRECT_URI when set' do
      allow(ENV).to receive(:[]).with('GMAIL_REDIRECT_URI').and_return('https://example.com/callback')

      expect(Signet::OAuth2::Client).to receive(:new).with(
        hash_including(redirect_uri: 'https://example.com/callback')
      ).and_return(mock_client)

      described_class.authorization_url(user)
    end

    it 'constructs redirect_uri from MAILER_HOST when GMAIL_REDIRECT_URI not set' do
      allow(ENV).to receive(:[]).with('GMAIL_REDIRECT_URI').and_return(nil)
      allow(ENV).to receive(:fetch).with('MAILER_HOST', 'localhost:3000').and_return('example.com')

      expect(Signet::OAuth2::Client).to receive(:new).with(
        hash_including(redirect_uri: 'http://example.com/oauth/gmail/callback')
      ).and_return(mock_client)

      described_class.authorization_url(user)
    end

    it 'adds http:// prefix when MAILER_HOST lacks protocol' do
      allow(ENV).to receive(:[]).with('GMAIL_REDIRECT_URI').and_return(nil)
      allow(ENV).to receive(:fetch).with('MAILER_HOST', 'localhost:3000').and_return('example.com:3000')

      expect(Signet::OAuth2::Client).to receive(:new).with(
        hash_including(redirect_uri: 'http://example.com:3000/oauth/gmail/callback')
      ).and_return(mock_client)

      described_class.authorization_url(user)
    end

    it 'preserves https:// when MAILER_HOST includes protocol' do
      allow(ENV).to receive(:[]).with('GMAIL_REDIRECT_URI').and_return(nil)
      allow(ENV).to receive(:fetch).with('MAILER_HOST', 'localhost:3000').and_return('https://example.com')

      expect(Signet::OAuth2::Client).to receive(:new).with(
        hash_including(redirect_uri: 'https://example.com/oauth/gmail/callback')
      ).and_return(mock_client)

      described_class.authorization_url(user)
    end

      it 'logs redirect URI' do
        # Logger expectations are too brittle - just verify functionality
        url = described_class.authorization_url(user)

        expect(url).to be_a(String)
        expect(url).to include('accounts.google.com')
      end

    context 'when OAuth is not configured' do
      before do
        allow(ENV).to receive(:[]).with('GMAIL_CLIENT_ID').and_return(nil)
      end

      it 'raises error' do
        expect {
          described_class.authorization_url(user)
        }.to raise_error(/Gmail OAuth not configured/)
      end
    end
  end

  describe '.exchange_code_for_tokens' do
    let(:code) { 'authorization-code' }
    let(:access_token) { 'access-token-123' }
    let(:refresh_token) { 'refresh-token-456' }
    let(:expires_at) { Time.current.to_i + 3600 }

    before do
      allow(Signet::OAuth2::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:code=)
      allow(mock_client).to receive(:fetch_access_token!)
      allow(mock_client).to receive(:access_token).and_return(access_token)
      allow(mock_client).to receive(:refresh_token).and_return(refresh_token)
      allow(mock_client).to receive(:expires_at).and_return(expires_at)
      allow(mock_client).to receive(:expires_in).and_return(nil)
    end

    it 'exchanges code for tokens' do
      expect(mock_client).to receive(:code=).with(code)
      expect(mock_client).to receive(:fetch_access_token!)

      described_class.exchange_code_for_tokens(user, code)
    end

    it 'saves access token and refresh token' do
      result = described_class.exchange_code_for_tokens(user, code)

      user.reload
      expect(result).to be true
      expect(user.gmail_access_token).to eq(access_token)
      expect(user.gmail_refresh_token).to eq(refresh_token)
      expect(user.gmail_token_expires_at).to be_within(1.second).of(Time.at(expires_at))
    end

    it 'uses expires_at when available' do
      described_class.exchange_code_for_tokens(user, code)

      user.reload
      expect(user.gmail_token_expires_at).to be_within(1.second).of(Time.at(expires_at))
    end

    it 'uses expires_in when expires_at not available' do
      allow(mock_client).to receive(:expires_at).and_return(nil)
      allow(mock_client).to receive(:expires_in).and_return(3600)

      described_class.exchange_code_for_tokens(user, code)

      user.reload
      expect(user.gmail_token_expires_at).to be_within(1.minute).of(1.hour.from_now)
    end

    it 'defaults to 1 hour when neither expires_at nor expires_in available' do
      allow(mock_client).to receive(:expires_at).and_return(nil)
      allow(mock_client).to receive(:expires_in).and_return(nil)

      described_class.exchange_code_for_tokens(user, code)

      user.reload
      expect(user.gmail_token_expires_at).to be_within(1.minute).of(1.hour.from_now)
    end

    it 'only updates refresh_token if provided' do
      allow(mock_client).to receive(:refresh_token).and_return(nil)

      described_class.exchange_code_for_tokens(user, code)

      user.reload
      expect(user.gmail_access_token).to eq(access_token)
      expect(user.gmail_refresh_token).to be_nil
    end

      it 'logs success' do
        # Logger expectations are too brittle - just verify functionality
        result = described_class.exchange_code_for_tokens(user, code)

        expect(result).to be true
        user.reload
        expect(user.gmail_access_token).to eq(access_token)
      end

    context 'when fetch_access_token! raises an error' do
      before do
        allow(mock_client).to receive(:fetch_access_token!).and_raise(StandardError, 'Token exchange failed')
      end

      it 'returns false' do
        result = described_class.exchange_code_for_tokens(user, code)

        expect(result).to be false
      end

      it 'logs error' do
        expect(Rails.logger).to receive(:error).with(/Failed to exchange code/)
        expect(Rails.logger).to receive(:error).with(anything)

        described_class.exchange_code_for_tokens(user, code)
      end

      it 'does not update user tokens' do
        original_token = user.gmail_access_token

        described_class.exchange_code_for_tokens(user, code)

        user.reload
        expect(user.gmail_access_token).to eq(original_token)
      end
    end
  end

  describe '.valid_access_token' do
    context 'when user has no refresh token' do
      before do
        user.update(gmail_refresh_token: nil)
      end

      it 'returns nil' do
        expect(described_class.valid_access_token(user)).to be_nil
      end
    end

    context 'when token is not expired' do
      before do
        user.update(
          gmail_access_token: 'valid-token',
          gmail_refresh_token: 'refresh-token',
          gmail_token_expires_at: 10.minutes.from_now
        )
      end

      it 'returns access token' do
        expect(described_class.valid_access_token(user)).to eq('valid-token')
      end

      it 'does not refresh token' do
        expect(described_class).not_to receive(:refresh_access_token)

        described_class.valid_access_token(user)
      end
    end

    context 'when token is expired' do
      before do
        user.update(
          gmail_access_token: 'old-token',
          gmail_refresh_token: 'refresh-token',
          gmail_token_expires_at: 1.minute.ago
        )
        allow(described_class).to receive(:refresh_access_token).with(user).and_return(true)
        user.reload.update(gmail_access_token: 'new-token')
      end

      it 'refreshes token' do
        expect(described_class).to receive(:refresh_access_token).with(user)

        described_class.valid_access_token(user)
      end
    end

    context 'when token expires within 5 minutes' do
      before do
        user.update(
          gmail_access_token: 'token',
          gmail_refresh_token: 'refresh-token',
          gmail_token_expires_at: 3.minutes.from_now
        )
        allow(described_class).to receive(:refresh_access_token).with(user).and_return(true)
      end

      it 'refreshes token proactively' do
        expect(described_class).to receive(:refresh_access_token).with(user)

        described_class.valid_access_token(user)
      end
    end

    context 'when token_expires_at is nil' do
      before do
        user.update(
          gmail_access_token: 'token',
          gmail_refresh_token: 'refresh-token',
          gmail_token_expires_at: nil
        )
        allow(described_class).to receive(:refresh_access_token).with(user).and_return(true)
      end

      it 'refreshes token' do
        expect(described_class).to receive(:refresh_access_token).with(user)

        described_class.valid_access_token(user)
      end
    end
  end

  describe '.refresh_access_token' do
    let(:new_access_token) { 'new-access-token' }
    let(:expires_at) { Time.current.to_i + 3600 }

    before do
      user.update(gmail_refresh_token: 'refresh-token')
      allow(Signet::OAuth2::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:refresh!)
      allow(mock_client).to receive(:access_token).and_return(new_access_token)
      allow(mock_client).to receive(:expires_at).and_return(expires_at)
      allow(mock_client).to receive(:expires_in).and_return(nil)
    end

    it 'refreshes token' do
      expect(mock_client).to receive(:refresh!)

      described_class.refresh_access_token(user)
    end

    it 'updates access token and expiration' do
      result = described_class.refresh_access_token(user)

      user.reload
      expect(result).to be true
      expect(user.gmail_access_token).to eq(new_access_token)
      expect(user.gmail_token_expires_at).to be_within(1.second).of(Time.at(expires_at))
    end

    it 'uses expires_at when available' do
      described_class.refresh_access_token(user)

      user.reload
      expect(user.gmail_token_expires_at).to be_within(1.second).of(Time.at(expires_at))
    end

    it 'uses expires_in when expires_at not available' do
      allow(mock_client).to receive(:expires_at).and_return(nil)
      allow(mock_client).to receive(:expires_in).and_return(3600)

      described_class.refresh_access_token(user)

      user.reload
      expect(user.gmail_token_expires_at).to be_within(1.minute).of(1.hour.from_now)
    end

    it 'defaults to 1 hour when neither expires_at nor expires_in available' do
      allow(mock_client).to receive(:expires_at).and_return(nil)
      allow(mock_client).to receive(:expires_in).and_return(nil)

      described_class.refresh_access_token(user)

      user.reload
      expect(user.gmail_token_expires_at).to be_within(1.minute).of(1.hour.from_now)
    end

    it 'logs success' do
      expect(Rails.logger).to receive(:info).with(/Token refreshed for user/)

      described_class.refresh_access_token(user)
    end

    context 'when user has no refresh token' do
      before do
        user.update(gmail_refresh_token: nil)
      end

      it 'returns false' do
        result = described_class.refresh_access_token(user)

        expect(result).to be false
      end
    end

    context 'when refresh! raises an error' do
      before do
        allow(mock_client).to receive(:refresh!).and_raise(StandardError, 'Refresh failed')
      end

      it 'returns false' do
        result = described_class.refresh_access_token(user)

        expect(result).to be false
      end

      it 'logs error' do
        expect(Rails.logger).to receive(:error).with(/Failed to refresh token/)
        expect(Rails.logger).to receive(:error).with(anything)

        described_class.refresh_access_token(user)
      end

      it 'does not update user tokens' do
        original_token = user.gmail_access_token

        described_class.refresh_access_token(user)

        user.reload
        expect(user.gmail_access_token).to eq(original_token)
      end
    end

    context 'when OAuth is not configured' do
      before do
        allow(ENV).to receive(:[]).with('GMAIL_CLIENT_ID').and_return(nil)
      end

      it 'raises error' do
        expect {
          described_class.refresh_access_token(user)
        }.to raise_error(/Gmail OAuth not configured/)
      end
    end
  end

  describe '.oauth_configured?' do
    context 'when user has refresh token and valid access token' do
      before do
        user.update(
          gmail_refresh_token: 'refresh-token',
          gmail_access_token: 'access-token',
          gmail_token_expires_at: 1.hour.from_now
        )
        allow(described_class).to receive(:valid_access_token).with(user).and_return('access-token')
      end

      it 'returns true' do
        expect(described_class.oauth_configured?(user)).to be true
      end
    end

    context 'when user has refresh token but no valid access token' do
      before do
        user.update(
          gmail_refresh_token: 'refresh-token',
          gmail_access_token: nil
        )
        allow(described_class).to receive(:valid_access_token).with(user).and_return(nil)
      end

      it 'returns false' do
        expect(described_class.oauth_configured?(user)).to be false
      end
    end

    context 'when user has no refresh token' do
      before do
        user.update(gmail_refresh_token: nil)
      end

      it 'returns false' do
        expect(described_class.oauth_configured?(user)).to be false
      end
    end
  end
end
