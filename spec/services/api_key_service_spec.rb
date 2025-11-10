require 'rails_helper'

RSpec.describe ApiKeyService, type: :service do
  let(:user) { build_stubbed(:user, llm_api_key: 'test-gemini-key', tavily_api_key: 'test-tavily-key') }

  describe '.get_gemini_api_key' do
    it 'returns the API key when present' do
      expect(described_class.get_gemini_api_key(user)).to eq('test-gemini-key')
    end

    it 'raises when the key is blank' do
      user.llm_api_key = ''

      expect {
        described_class.get_gemini_api_key(user)
      }.to raise_error(ArgumentError, 'Gemini API key is required. Please add your Gemini API key in the API Keys section.')
    end

    it 'raises when the key is nil' do
      user.llm_api_key = nil

      expect {
        described_class.get_gemini_api_key(user)
      }.to raise_error(ArgumentError, 'Gemini API key is required. Please add your Gemini API key in the API Keys section.')
    end
  end

  describe '.get_tavily_api_key' do
    it 'returns the API key when present' do
      expect(described_class.get_tavily_api_key(user)).to eq('test-tavily-key')
    end

    it 'raises when the key is blank' do
      user.tavily_api_key = ''

      expect {
        described_class.get_tavily_api_key(user)
      }.to raise_error(ArgumentError, 'Tavily API key is required. Please add your Tavily API key in the API Keys section.')
    end

    it 'raises when the key is nil' do
      user.tavily_api_key = nil

      expect {
        described_class.get_tavily_api_key(user)
      }.to raise_error(ArgumentError, 'Tavily API key is required. Please add your Tavily API key in the API Keys section.')
    end
  end

  describe '.keys_available?' do
    it 'returns true when both keys are present' do
      expect(described_class.keys_available?(user)).to be true
    end

    it 'returns false when any key is blank' do
      user.llm_api_key = ''

      expect(described_class.keys_available?(user)).to be false
    end

    it 'returns false when user is nil' do
      expect(described_class.keys_available?(nil)).to be false
    end
  end

  describe '.missing_keys' do
    it 'returns empty array when no keys are missing' do
      expect(described_class.missing_keys(user)).to eq([])
    end

    it 'returns Gemini when Gemini key missing' do
      user.llm_api_key = ''

      expect(described_class.missing_keys(user)).to eq([ 'Gemini' ])
    end

    it 'returns Tavily when Tavily key missing' do
      user.llm_api_key = 'value'
      user.tavily_api_key = ''

      expect(described_class.missing_keys(user)).to eq([ 'Tavily' ])
    end

    it 'returns both when both missing' do
      user.llm_api_key = nil
      user.tavily_api_key = nil

      expect(described_class.missing_keys(user)).to match_array([ 'Gemini', 'Tavily' ])
    end

    it 'handles nil user' do
      expect(described_class.missing_keys(nil)).to match_array([ 'Gemini', 'Tavily' ])
    end
  end
end
