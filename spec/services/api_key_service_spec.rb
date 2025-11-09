require 'rails_helper'

RSpec.describe ApiKeyService, type: :service do
  describe '.get_gemini_api_key' do
    context 'when API key is present' do
      let(:session) { { llm_api_key: 'test-gemini-key' } }

      it 'returns the API key' do
        expect(described_class.get_gemini_api_key(session)).to eq('test-gemini-key')
      end
    end

    context 'when API key is missing' do
      let(:session) { {} }

      it 'raises ArgumentError with descriptive message' do
        expect {
          described_class.get_gemini_api_key(session)
        }.to raise_error(ArgumentError, 'Gemini API key is required. Please add your Gemini API key in the API Keys section.')
      end
    end

    context 'when API key is blank' do
      let(:session) { { llm_api_key: '' } }

      it 'raises ArgumentError with descriptive message' do
        expect {
          described_class.get_gemini_api_key(session)
        }.to raise_error(ArgumentError, 'Gemini API key is required. Please add your Gemini API key in the API Keys section.')
      end
    end

    context 'when API key is nil' do
      let(:session) { { llm_api_key: nil } }

      it 'raises ArgumentError with descriptive message' do
        expect {
          described_class.get_gemini_api_key(session)
        }.to raise_error(ArgumentError, 'Gemini API key is required. Please add your Gemini API key in the API Keys section.')
      end
    end
  end

  describe '.get_tavily_api_key' do
    context 'when API key is present' do
      let(:session) { { tavily_api_key: 'test-tavily-key' } }

      it 'returns the API key' do
        expect(described_class.get_tavily_api_key(session)).to eq('test-tavily-key')
      end
    end

    context 'when API key is missing' do
      let(:session) { {} }

      it 'raises ArgumentError with descriptive message' do
        expect {
          described_class.get_tavily_api_key(session)
        }.to raise_error(ArgumentError, 'Tavily API key is required. Please add your Tavily API key in the API Keys section.')
      end
    end

    context 'when API key is blank' do
      let(:session) { { tavily_api_key: '' } }

      it 'raises ArgumentError with descriptive message' do
        expect {
          described_class.get_tavily_api_key(session)
        }.to raise_error(ArgumentError, 'Tavily API key is required. Please add your Tavily API key in the API Keys section.')
      end
    end

    context 'when API key is nil' do
      let(:session) { { tavily_api_key: nil } }

      it 'raises ArgumentError with descriptive message' do
        expect {
          described_class.get_tavily_api_key(session)
        }.to raise_error(ArgumentError, 'Tavily API key is required. Please add your Tavily API key in the API Keys section.')
      end
    end
  end

  describe '.keys_available?' do
    context 'when both keys are present' do
      let(:session) do
        {
          llm_api_key: 'test-gemini-key',
          tavily_api_key: 'test-tavily-key'
        }
      end

      it 'returns true' do
        expect(described_class.keys_available?(session)).to be true
      end
    end

    context 'when only one key is present' do
      let(:session) { { llm_api_key: 'test-gemini-key' } }

      it 'returns false' do
        expect(described_class.keys_available?(session)).to be false
      end
    end

    context 'when no keys are present' do
      let(:session) { {} }

      it 'returns false' do
        expect(described_class.keys_available?(session)).to be false
      end
    end

    context 'when keys are blank' do
      let(:session) do
        {
          llm_api_key: '',
          tavily_api_key: ''
        }
      end

      it 'returns false' do
        expect(described_class.keys_available?(session)).to be false
      end
    end

    context 'when keys are nil' do
      let(:session) do
        {
          llm_api_key: nil,
          tavily_api_key: nil
        }
      end

      it 'returns false' do
        expect(described_class.keys_available?(session)).to be false
      end
    end
  end

  describe '.missing_keys' do
    context 'when both keys are present' do
      let(:session) do
        {
          llm_api_key: 'test-gemini-key',
          tavily_api_key: 'test-tavily-key'
        }
      end

      it 'returns empty array' do
        expect(described_class.missing_keys(session)).to eq([])
      end
    end

    context 'when only Gemini key is missing' do
      let(:session) { { tavily_api_key: 'test-tavily-key' } }

      it 'returns array with Gemini' do
        expect(described_class.missing_keys(session)).to eq([ 'Gemini' ])
      end
    end

    context 'when only Tavily key is missing' do
      let(:session) { { llm_api_key: 'test-gemini-key' } }

      it 'returns array with Tavily' do
        expect(described_class.missing_keys(session)).to eq([ 'Tavily' ])
      end
    end

    context 'when both keys are missing' do
      let(:session) { {} }

      it 'returns array with both keys' do
        expect(described_class.missing_keys(session)).to eq([ 'Gemini', 'Tavily' ])
      end
    end

    context 'when keys are blank' do
      let(:session) do
        {
          llm_api_key: '',
          tavily_api_key: ''
        }
      end

      it 'returns array with both keys' do
        expect(described_class.missing_keys(session)).to eq([ 'Gemini', 'Tavily' ])
      end
    end

    context 'when keys are nil' do
      let(:session) do
        {
          llm_api_key: nil,
          tavily_api_key: nil
        }
      end

      it 'returns array with both keys' do
        expect(described_class.missing_keys(session)).to eq([ 'Gemini', 'Tavily' ])
      end
    end
  end

  describe 'constants' do
    it 'defines LLM_KEY_NAME as symbol' do
      expect(described_class::LLM_KEY_NAME).to eq(:llm_api_key)
    end

    it 'defines TAVILY_KEY_NAME as symbol' do
      expect(described_class::TAVILY_KEY_NAME).to eq(:tavily_api_key)
    end
  end
end
