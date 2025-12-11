require 'rails_helper'

RSpec.describe SettingsHelper do
  let(:helper) { Class.new { include SettingsHelper }.new }
  let(:settings) do
    {
      'tone' => 'friendly',
      :brand_voice => {
        'tone' => 'professional',
        :style => 'casual'
      },
      :theme => 'dark',
      'empty' => '',
      :nil_value => nil
    }
  end

  describe '#get_setting' do
    it 'returns value for string key' do
      expect(helper.send(:get_setting, settings, 'tone')).to eq('friendly')
    end

    it 'returns value for symbol key' do
      expect(helper.send(:get_setting, settings, :theme)).to eq('dark')
    end

    it 'returns nil for missing key' do
      expect(helper.send(:get_setting, settings, :missing)).to be_nil
    end

    it 'returns nil if hash is nil' do
      expect(helper.send(:get_setting, nil, :tone)).to be_nil
    end

    it 'returns nil if not a hash' do
      expect(helper.send(:get_setting, 'not a hash', :tone)).to be_nil
    end
  end

  describe '#dig_setting' do
    it 'digs through nested hashes with symbol keys' do
      expect(helper.send(:dig_setting, settings, :brand_voice, :style)).to eq('casual')
    end

    it 'digs through nested hashes with string keys' do
      expect(helper.send(:dig_setting, settings, :brand_voice, 'tone')).to eq('professional')
    end

    it 'returns nil if any key is missing' do
      expect(helper.send(:dig_setting, settings, :brand_voice, :missing)).to be_nil
    end

    it 'returns nil if hash is nil' do
      expect(helper.send(:dig_setting, nil, :brand_voice)).to be_nil
    end

    it 'returns hash if no keys given' do
      expect(helper.send(:dig_setting, settings)).to eq(settings)
    end
  end

  describe '#get_setting_with_default' do
    it 'returns value if present' do
      expect(helper.send(:get_setting_with_default, settings, :theme, 'light')).to eq('dark')
    end

    it 'returns default if value is nil' do
      expect(helper.send(:get_setting_with_default, settings, :nil_value, 'default')).to eq('default')
    end

    it 'returns default if key is missing' do
      expect(helper.send(:get_setting_with_default, settings, :missing, 'default')).to eq('default')
    end
  end

  describe '#get_settings' do
    it 'returns hash of found keys' do
      result = helper.send(:get_settings, settings, :theme, 'tone', :missing)
      expect(result).to eq({ theme: 'dark', tone: 'friendly' })
    end

    it 'returns empty hash if not a hash' do
      expect(helper.send(:get_settings, 'not a hash', :theme)).to eq({})
    end
  end

  describe '#setting_present?' do
    it 'returns true for present value' do
      expect(helper.send(:setting_present?, settings, :theme)).to be true
    end

    it 'returns false for nil value' do
      expect(helper.send(:setting_present?, settings, :nil_value)).to be false
    end

    it 'returns false for empty string value' do
      expect(helper.send(:setting_present?, settings, 'empty')).to be false
    end

    it 'returns false for missing key' do
      expect(helper.send(:setting_present?, settings, :missing)).to be false
    end
  end

  describe 'module methods' do
    it 'get_setting works as module method' do
      expect(SettingsHelper.get_setting(settings, :theme)).to eq('dark')
    end

    it 'dig_setting works as module method' do
      expect(SettingsHelper.dig_setting(settings, :brand_voice, :style)).to eq('casual')
    end

    it 'get_setting_with_default works as module method' do
      expect(SettingsHelper.get_setting_with_default(settings, :missing, 'default')).to eq('default')
    end
  end

  describe 'ClassMethods' do
    let(:klass) do
      Class.new do
        extend SettingsHelper::ClassMethods
        def self.get_settings(hash, *keys)
          result = {}
          keys.each do |key|
            value = get_setting(hash, key)
            result[key.to_sym] = value unless value.nil?
          end
          result
        end
      end
    end

    it 'get_setting works in ClassMethods' do
      expect(klass.send(:get_setting, settings, :theme)).to eq('dark')
    end

    it 'dig_setting works in ClassMethods' do
      expect(klass.send(:dig_setting, settings, :brand_voice, 'tone')).to eq('professional')
    end

    it 'get_settings works in ClassMethods' do
      result = klass.send(:get_settings, settings, :theme, 'tone')
      expect(result).to eq({ theme: 'dark', tone: 'friendly' })
    end

    it 'get_setting_with_default works in ClassMethods' do
      expect(klass.send(:get_setting_with_default, settings, :missing, 'default')).to eq('default')
    end
  end
end
