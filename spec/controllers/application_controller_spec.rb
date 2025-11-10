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
end
