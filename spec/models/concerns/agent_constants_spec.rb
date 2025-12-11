require 'rails_helper'

describe AgentConstants do
  describe '.extract_rewrite_count' do
    it 'returns the count for valid rewritten stage' do
      expect(described_class.extract_rewrite_count('rewritten (1)')).to eq(1)
      expect(described_class.extract_rewrite_count('rewritten(2)')).to eq(2)
      expect(described_class.extract_rewrite_count('rewritten   (11)')).to eq(11)
    end

    it 'returns nil for non-rewritten stage' do
      expect(described_class.extract_rewrite_count('written')).to be_nil
      expect(described_class.extract_rewrite_count('searched')).to be_nil
      expect(described_class.extract_rewrite_count(nil)).to be_nil
      expect(described_class.extract_rewrite_count('')).to be_nil
    end

    it 'returns nil for rewritten stage without count' do
      expect(described_class.extract_rewrite_count('rewritten')).to be_nil
      expect(described_class.extract_rewrite_count('rewritten ()')).to be_nil
      expect(described_class.extract_rewrite_count('rewritten (abc)')).to be_nil
    end
  end
end
