require 'rails_helper'

RSpec.describe CampaignsController, type: :controller do
  include Devise::Test::ControllerHelpers

  describe '#current_user' do
    controller(CampaignsController) do
      def index
        render plain: 'test'
      end
    end

    context 'when skip_auth? is true' do
      before do
        allow(controller).to receive(:skip_auth?).and_return(true)
        # Stub warden to avoid MissingWarden error
        allow(controller).to receive(:respond_to?).and_call_original
        allow(controller).to receive(:respond_to?).with(:warden).and_return(false)
      end

      context 'when admin user exists with all fields' do
        let!(:admin_user) { create(:user, email: 'admin@example.com', first_name: 'Admin', last_name: 'User', workspace_name: 'Admin Workspace', job_title: 'Administrator') }

        it 'returns existing admin user without updating' do
          expect {
            controller.send(:current_user)
          }.not_to change { admin_user.reload.updated_at }
        end
      end

      context 'when admin user exists but missing fields' do
        let!(:admin_user) { create(:user, email: 'admin@example.com', first_name: nil, workspace_name: nil) }

        it 'updates missing fields' do
          controller.send(:current_user)
          admin_user.reload
          expect(admin_user.first_name).to eq('Admin')
          expect(admin_user.last_name).to eq('User')
          expect(admin_user.workspace_name).to eq('Admin Workspace')
          expect(admin_user.job_title).to eq('Administrator')
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
      end
    end

    context 'when skip_auth? is false' do
      before do
        allow(controller).to receive(:skip_auth?).and_return(false)
      end

      context 'when authenticated user exists from warden' do
        let(:user) { create(:user) }

        before do
          allow(controller).to receive(:respond_to?).and_call_original
          allow(controller).to receive(:respond_to?).with(:warden).and_return(true)
          allow(controller).to receive(:warden).and_return(double(user: user))
        end

        it 'returns the authenticated user' do
          result = controller.send(:current_user)
          expect(result).to eq(user)
        end

        it 'normalizes the user' do
          expect(controller).to receive(:normalize_user).with(user).and_call_original
          controller.send(:current_user)
        end
      end

      context 'when warden is not available' do
        before do
          allow(controller).to receive(:respond_to?).and_call_original
          allow(controller).to receive(:respond_to?).with(:warden).and_return(false)
        end

        it 'returns nil' do
          result = controller.send(:current_user)
          expect(result).to be_nil
        end
      end
    end
  end
end

