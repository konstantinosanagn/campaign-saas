require 'rails_helper'

RSpec.describe ProfilesController, type: :controller do
  include Devise::Test::ControllerHelpers
  let(:user) { create(:user) }

  describe 'before_action' do
    it 'requires authentication' do
      get :edit
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'GET #edit' do
    before { sign_in user }

    it 'assigns current_user to @user' do
      get :edit
      expect(assigns(:user)).to eq(user)
    end

    it 'renders the edit template' do
      get :edit
      expect(response).to render_template(:edit)
    end
  end

  describe 'PATCH #update' do
    before { sign_in user }

    context 'with valid params' do
      let(:valid_params) do
        {
          user: {
            workspace_name: 'New Workspace',
            job_title: 'Developer'
          }
        }
      end

      it 'updates the user profile' do
        patch :update, params: valid_params
        user.reload
        expect(user.workspace_name).to eq('New Workspace')
        expect(user.job_title).to eq('Developer')
      end

      it 'redirects to after_sign_in_path_for with notice' do
        allow(controller).to receive(:after_sign_in_path_for).and_return('/dashboard')
        patch :update, params: valid_params
        expect(response).to redirect_to('/dashboard')
        expect(flash[:notice]).to eq('Profile updated!')
      end
    end

    context 'with invalid params' do
      let(:invalid_params) do
        {
          user: {
            workspace_name: '',
            job_title: ''
          }
        }
      end

      before do
        allow_any_instance_of(User).to receive(:update).and_return(false)
      end

      it 'does not update the user profile' do
        patch :update, params: invalid_params
        expect(response).to render_template(:edit)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it 'permits only allowed parameters' do
      expect_any_instance_of(ActionController::Parameters).to receive(:permit).with(:workspace_name, :job_title).and_return({ workspace_name: 'Test', job_title: 'Test' })
      patch :update, params: { user: { workspace_name: 'Test', job_title: 'Test', admin: true } }
    end
  end
end
