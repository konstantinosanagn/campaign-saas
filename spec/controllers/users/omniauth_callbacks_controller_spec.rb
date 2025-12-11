require 'rails_helper'
require 'ostruct'

RSpec.describe Users::OmniauthCallbacksController, type: :controller do
  describe '#google_oauth2' do
    let(:credentials) do
      OpenStruct.new(
        token: 'access-token',
        refresh_token: 'refresh-token',
        expires_at: Time.now.to_i + 3600
      )
    end

    let(:info) do
      OpenStruct.new(email: 'user@example.com')
    end

    let(:auth_object) do
      double('OmniAuth::Auth',
        provider: 'google_oauth2',
        uid: '123456789',
        info: info,
        credentials: credentials
      )
    end

    before do
      request.env['devise.mapping'] = Devise.mappings[:user]
      request.env['omniauth.auth'] = auth_object
    end

    context 'when user is persisted and profile is complete' do
      let(:user) { instance_double(User, persisted?: true, profile_complete?: true, gmail_refresh_token: nil) }

      before do
        allow(User).to receive(:from_google_omniauth).and_return(user)
        allow(user).to receive(:update!)
        allow(controller).to receive(:sign_in)
        allow(controller).to receive(:after_sign_in_path_for).and_return('/dashboard')
      end

      it 'updates user tokens and redirects to dashboard' do
        expect(user).to receive(:update!).with(hash_including(
          gmail_access_token: 'access-token',
          gmail_refresh_token: 'refresh-token',
          gmail_token_expires_at: kind_of(Time),
          gmail_email: 'user@example.com'
        ))
        expect(controller).to receive(:sign_in).with(user, event: :authentication)
        get :google_oauth2
        expect(response).to redirect_to('/dashboard')
      end
    end

    context 'when user is persisted but profile is incomplete' do
      let(:user) { instance_double(User, persisted?: true, profile_complete?: false, gmail_refresh_token: nil) }

      before do
        allow(User).to receive(:from_google_omniauth).and_return(user)
        allow(user).to receive(:update!)
        allow(controller).to receive(:sign_in)
        allow(controller).to receive(:complete_profile_path).and_return('/complete_profile')
      end

      it 'updates user tokens and redirects to complete_profile' do
        expect(user).to receive(:update!).with(hash_including(
          gmail_access_token: 'access-token',
          gmail_refresh_token: 'refresh-token',
          gmail_token_expires_at: kind_of(Time),
          gmail_email: 'user@example.com'
        ))
        expect(controller).to receive(:sign_in).with(user, event: :authentication)
        get :google_oauth2
        expect(response).to redirect_to('/complete_profile')
      end
    end

    context 'when user is not persisted' do
      let(:user) { instance_double(User, persisted?: false) }

      let(:auth_with_except) do
        double('OmniAuth::Auth',
          provider: 'google_oauth2',
          uid: '123456789',
          info: info,
          credentials: credentials,
          except: auth_object # returns the double directly
        )
      end

      before do
        allow(User).to receive(:from_google_omniauth).and_return(user)
        request.env['omniauth.auth'] = auth_with_except
      end

      it 'sets session and redirects to registration with alert' do
        get :google_oauth2
        expect(session['devise.google_data']).to eq(auth_object)
        expect(response).to redirect_to(new_user_registration_url)
        expect(flash[:alert]).to eq('There was a problem signing you in through Google. Please register or try again.')
      end
    end

    context 'when refresh_token is nil on subsequent logins' do
      let(:user) { instance_double(User, persisted?: true, profile_complete?: true, gmail_refresh_token: 'existing-refresh-token') }
      let(:credentials_with_nil_refresh) do
        OpenStruct.new(
          token: 'access-token',
          refresh_token: nil,
          expires_at: Time.now.to_i + 3600
        )
      end

      let(:auth_object_with_nil_refresh) do
        double('OmniAuth::Auth',
          provider: 'google_oauth2',
          uid: '123456789',
          info: info,
          credentials: credentials_with_nil_refresh
        )
      end

      before do
        request.env['omniauth.auth'] = auth_object_with_nil_refresh
        allow(User).to receive(:from_google_omniauth).and_return(user)
        allow(user).to receive(:update!)
        allow(controller).to receive(:sign_in)
        allow(controller).to receive(:after_sign_in_path_for).and_return('/dashboard')
      end

      it 'does not overwrite existing refresh_token if nil' do
        expect(user).to receive(:update!).with(hash_including(
          gmail_refresh_token: 'existing-refresh-token'
        ))
        get :google_oauth2
      end
    end
  end
end
