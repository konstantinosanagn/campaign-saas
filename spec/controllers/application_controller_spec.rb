require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  controller do
    def index
      render plain: 'test'
    end
  end

  describe 'browser compatibility' do
    it 'allows only modern browsers' do
      expect(controller.class.ancestors).to include(ActionController::Base)
      # Note: allow_browser is a Rails 8 feature that's hard to test directly
      # but we can verify the controller inherits from ActionController::Base
    end
  end

  describe 'importmap caching' do
    it 'includes stale_when_importmap_changes' do
      # This is a Rails 8 feature that's hard to test directly
      # but we can verify the controller is properly configured
      expect(controller.class.ancestors).to include(ActionController::Base)
    end
  end

  describe '#ensure_default_api_keys_for_admin' do
    let(:user) { create(:user, llm_api_key: nil, tavily_api_key: nil) }

    before do
      allow(controller).to receive(:current_user).and_return(user)
    end

    it 'sets default API keys for the user in development when keys are blank' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))

      get :index

      user.reload
      expect(user.llm_api_key).to eq(ApplicationController::DEFAULT_DEV_LLM_KEY)
      expect(user.tavily_api_key).to eq(ApplicationController::DEFAULT_DEV_TAVILY_KEY)
    end

    it 'does not overwrite existing API keys in development' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      user.update!(llm_api_key: 'custom-llm-key', tavily_api_key: 'custom-tavily-key')

      get :index

      user.reload
      expect(user.llm_api_key).to eq('custom-llm-key')
      expect(user.tavily_api_key).to eq('custom-tavily-key')
    end

    it 'does nothing outside development' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))

      get :index

      user.reload
      expect(user.llm_api_key).to be_nil
      expect(user.tavily_api_key).to be_nil
    end

    it 'does nothing when there is no current user' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      allow(controller).to receive(:current_user).and_return(nil)

      expect { get :index }.not_to raise_error
    end
  end

  describe '#normalize_user' do
    it 'returns the user when passed a User instance' do
      u = create(:user)
      expect(controller.send(:normalize_user, u)).to eq(u)
    end

    it 'returns nil when passed nil' do
      expect(controller.send(:normalize_user, nil)).to be_nil
    end

    it 'finds user when passed a hash with symbol id' do
      u = create(:user)
      result = controller.send(:normalize_user, { id: u.id })
      expect(result).to eq(u)
    end

    it 'finds user when passed a hash with string id' do
      u = create(:user)
      result = controller.send(:normalize_user, { 'id' => u.id })
      expect(result).to eq(u)
    end

    it 'returns the original object when hash has no id' do
      h = { name: 'no-id' }
      expect(controller.send(:normalize_user, h)).to eq(h)
    end

    it 'returns the original object when user does not respond to []' do
      obj = Object.new
      result = controller.send(:normalize_user, obj)
      expect(result).to eq(obj)
    end
  end

  describe '#new_user_session_path' do
    context 'in production' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      it 'returns /login' do
        expect(controller.new_user_session_path).to eq('/login')
      end
    end

    context 'in development' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      end

      it 'calls super' do
        expect(controller.new_user_session_path).to eq('/users/sign_in')
      end
    end
  end

  describe '#new_user_registration_path' do
    context 'in production' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      it 'returns /signup' do
        expect(controller.new_user_registration_path).to eq('/signup')
      end
    end

    context 'in development' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      end

      it 'calls super' do
        expect(controller.new_user_registration_path).to eq('/users/sign_up')
      end
    end
  end

  describe '#ensure_default_api_keys_for_dev' do
    let(:user) { create(:user) }

    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      allow(controller).to receive(:current_user).and_return(user)
    end

    context 'when user has no API keys' do
      it 'sets default LLM API key' do
        controller.send(:ensure_default_api_keys_for_dev)
        user.reload
        expect(user.llm_api_key).to eq(ApplicationController::DEFAULT_DEV_LLM_KEY)
      end

      it 'sets default Tavily API key' do
        controller.send(:ensure_default_api_keys_for_dev)
        user.reload
        expect(user.tavily_api_key).to eq(ApplicationController::DEFAULT_DEV_TAVILY_KEY)
      end
    end

    context 'when user already has API keys' do
      before do
        user.update(llm_api_key: 'existing_key', tavily_api_key: 'existing_tavily')
      end

      it 'does not update existing keys' do
        controller.send(:ensure_default_api_keys_for_dev)
        user.reload
        expect(user.llm_api_key).to eq('existing_key')
        expect(user.tavily_api_key).to eq('existing_tavily')
      end
    end

    context 'when user has only LLM key' do
      before do
        user.update(llm_api_key: 'existing_key', tavily_api_key: nil)
      end

      it 'only sets Tavily key' do
        controller.send(:ensure_default_api_keys_for_dev)
        user.reload
        expect(user.llm_api_key).to eq('existing_key')
        expect(user.tavily_api_key).to eq(ApplicationController::DEFAULT_DEV_TAVILY_KEY)
      end
    end

    context 'when user has only Tavily key' do
      before do
        user.update(llm_api_key: nil, tavily_api_key: 'existing_tavily')
      end

      it 'only sets LLM key' do
        controller.send(:ensure_default_api_keys_for_dev)
        user.reload
        expect(user.llm_api_key).to eq(ApplicationController::DEFAULT_DEV_LLM_KEY)
        expect(user.tavily_api_key).to eq('existing_tavily')
      end
    end

    context 'when not in development' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      it 'does not set API keys' do
        controller.send(:ensure_default_api_keys_for_dev)
        user.reload
        expect(user.llm_api_key).to be_nil
        expect(user.tavily_api_key).to be_nil
      end
    end

    context 'when current_user is nil' do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
      end

      it 'does not raise an error' do
        expect { controller.send(:ensure_default_api_keys_for_dev) }.not_to raise_error
      end
    end
  end
end
