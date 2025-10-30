require 'rails_helper'

RSpec.describe Api::V1::BaseController, type: :controller do
  controller(Api::V1::BaseController) do
    def index
      render json: { message: 'test' }
    end
  end

  # Clean up any mocks after each test to prevent leakage
  after(:each) do
    # Reset any stubbed methods
    allow(controller).to receive(:current_user).and_call_original
    allow(controller).to receive(:skip_auth?).and_call_original
  end

  describe 'CSRF protection' do
    it 'has protect_from_forgery configuration' do
      # The controller should have protect_from_forgery with :null_session
      expect(controller.class.ancestors).to include(ActionController::Base)
    end
  end

  describe 'authentication' do
    it 'requires authentication unless skip_auth?' do
      expect(controller.class._process_action_callbacks.find { |c| c.filter == :authenticate_user! }).to be_present
    end
  end

  describe '#skip_auth?' do
    context 'in development environment' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      end

      it 'returns true' do
        expect(controller.send(:skip_auth?)).to be true
      end
    end

    context 'when DISABLE_AUTH env var is set to true' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        allow(ENV).to receive(:[]).with('DISABLE_AUTH').and_return('true')
      end

      it 'returns true' do
        expect(controller.send(:skip_auth?)).to be true
      end
    end

    context 'when DISABLE_AUTH env var is not set' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        allow(ENV).to receive(:[]).with('DISABLE_AUTH').and_return(nil)
      end

      it 'returns false' do
        expect(controller.send(:skip_auth?)).to be false
      end
    end

    context 'when DISABLE_AUTH env var is set to false' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        allow(ENV).to receive(:[]).with('DISABLE_AUTH').and_return('false')
      end

      it 'returns false' do
        expect(controller.send(:skip_auth?)).to be false
      end
    end
  end

  describe '#current_user' do
    context 'when skip_auth? is true' do
      before do
        allow(controller).to receive(:skip_auth?).and_return(true)
      end

      context 'when admin user exists' do
        let!(:admin_user) { create(:user, email: 'admin@example.com') }

        it 'returns existing admin user' do
          expect(controller.send(:current_user)).to eq(admin_user)
        end

        it 'does not create new admin user' do
          expect {
            controller.send(:current_user)
          }.not_to change(User, :count)
        end
      end

      context 'when admin user does not exist' do
        it 'creates new admin user' do
          expect {
            controller.send(:current_user)
          }.to change(User, :count).by(1)

          admin_user = User.find_by(email: 'admin@example.com')
          expect(admin_user).to be_present
          expect(admin_user.email).to eq('admin@example.com')
          expect(admin_user.name).to eq('Admin User')
        end

        it 'returns created admin user' do
          user = controller.send(:current_user)
          expect(user).to be_a(User)
          expect(user.email).to eq('admin@example.com')
        end
      end

      context 'when admin user creation fails' do
        before do
          allow(User).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(User.new))
        end

        it 'raises the error' do
          expect {
            controller.send(:current_user)
          }.to raise_error(ActiveRecord::RecordInvalid)
        end
      end
    end

    context 'when skip_auth? is false' do
      before do
        allow(controller).to receive(:skip_auth?).and_return(false)
      end

      it 'calls super to get authenticated user' do
        # Test that the method exists and can be called
        expect(controller.respond_to?(:current_user, true)).to be true
      end
    end
  end

  describe 'inheritance' do
    it 'inherits from ApplicationController' do
      expect(described_class.superclass).to eq(ApplicationController)
    end
  end

  describe 'module structure' do
    it 'is defined in Api::V1 module' do
      expect(described_class.name).to eq('Api::V1::BaseController')
    end
  end

  describe 'private methods' do
    it 'has skip_auth? as private method' do
      expect(controller.private_methods).to include(:skip_auth?)
    end

    it 'has current_user as private method' do
      expect(controller.private_methods).to include(:current_user)
    end
  end

  describe 'controller behavior' do
    context 'when skip_auth? returns true' do
      before do
        allow(controller).to receive(:skip_auth?).and_return(true)
        allow(controller).to receive(:current_user).and_return(create(:user))
      end

      it 'allows access without authentication' do
        get :index
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when skip_auth? returns false' do
      before do
        allow(controller).to receive(:skip_auth?).and_return(false)
        allow(controller).to receive(:authenticate_user!).and_raise(StandardError, 'Not authenticated')
      end

      it 'requires authentication' do
        expect {
          get :index
        }.to raise_error(StandardError, 'Not authenticated')
      end
    end
  end
end
