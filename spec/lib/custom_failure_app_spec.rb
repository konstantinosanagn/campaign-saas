require 'rails_helper'

RSpec.describe CustomFailureApp do
  let(:scope) { :user }
  let(:request) { double(path: '/users/sign_in', referer: nil) }
  let(:env) do
    {
      'warden.options' => { scope: scope },
      'REQUEST_METHOD' => 'POST',
      'PATH_INFO' => '/users/sign_in',
      'action_dispatch.request' => request
    }
  end

  let(:failure_app) do
    # Devise::FailureApp is instantiated by Warden internally
    # For testing, we create it and set up the necessary mocks
    app = described_class.new
    # Set up the request and warden_options that the app needs
    allow(app).to receive(:request).and_return(request)
    allow(app).to receive(:warden_options).and_return(scope: scope)
    app
  end

  describe '#redirect_url' do
    context 'in production' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      context 'when scope is :user' do
        context 'when request path is /signup' do
          let(:request) { double(path: '/signup', referer: nil) }

          it 'returns /signup' do
            expect(failure_app.redirect_url).to eq('/signup')
          end
        end

        context 'when request path is /users/sign_up' do
          let(:request) { double(path: '/users/sign_up', referer: nil) }

          it 'returns /signup' do
            expect(failure_app.redirect_url).to eq('/signup')
          end
        end

        context 'when referer includes /signup' do
          let(:request) { double(path: '/users/sign_in', referer: 'http://example.com/signup') }

          it 'returns /signup' do
            expect(failure_app.redirect_url).to eq('/signup')
          end
        end

        context 'when referer includes /users/sign_up' do
          let(:request) { double(path: '/users/sign_in', referer: 'http://example.com/users/sign_up') }

          it 'returns /signup' do
            expect(failure_app.redirect_url).to eq('/signup')
          end
        end

        context 'when request is for login' do
          let(:request) { double(path: '/users/sign_in', referer: nil) }

          it 'returns /login' do
            expect(failure_app.redirect_url).to eq('/login')
          end
        end
      end

      context 'when scope is not :user' do
        let(:scope) { :admin }

        it 'calls super' do
          allow_any_instance_of(Devise::FailureApp).to receive(:redirect_url).and_return('/default')
          expect(failure_app.redirect_url).to eq('/default')
        end
      end
    end

    context 'in development' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      end

      it 'calls super' do
        allow_any_instance_of(Devise::FailureApp).to receive(:redirect_url).and_return('/default')
        expect(failure_app.redirect_url).to eq('/default')
      end
    end
  end
end
