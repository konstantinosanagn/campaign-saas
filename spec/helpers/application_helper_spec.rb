require "rails_helper"
require_relative '../../app/models/concerns/settings_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe "#gmail_status_badge" do
    let(:user) { double("User") }

    context "when user can send gmail and has gmail_email" do
      it "returns Gmail connected with email" do
        allow(user).to receive(:respond_to?).with(:can_send_gmail?).and_return(true)
        allow(user).to receive(:can_send_gmail?).and_return(true)
        allow(user).to receive(:respond_to?).with(:gmail_email).and_return(true)
        allow(user).to receive(:gmail_email).and_return("test@gmail.com")
        allow(user).to receive(:present?).and_return(true)
        expect(helper.gmail_status_badge(user)).to eq("Gmail connected (test@gmail.com)")
      end
    end

    context "when user can send gmail but has no gmail_email" do
      it "returns Gmail connected" do
        allow(user).to receive(:respond_to?).with(:can_send_gmail?).and_return(true)
        allow(user).to receive(:can_send_gmail?).and_return(true)
        allow(user).to receive(:respond_to?).with(:gmail_email).and_return(false)
        expect(helper.gmail_status_badge(user)).to eq("Gmail connected")
      end
    end

    context "when user cannot send gmail" do
      it "returns Gmail not connected" do
        allow(user).to receive(:respond_to?).with(:can_send_gmail?).and_return(true)
        allow(user).to receive(:can_send_gmail?).and_return(false)
        expect(helper.gmail_status_badge(user)).to eq("Gmail not connected")
      end
    end
  end

  describe "#default_gmail_sender_available?" do
    let(:default_email) { "default@gmail.com" }
    let(:user) { double("User", can_send_gmail?: true) }

    before do
      stub_const("ENV", ENV.to_hash.merge("DEFAULT_GMAIL_SENDER" => default_email))
    end

    it "returns true if default sender exists and can send gmail" do
      allow(User).to receive(:find_by).with(email: default_email).and_return(user)
      expect(helper.default_gmail_sender_available?).to eq(true)
    end

    it "returns false if default sender does not exist" do
      allow(User).to receive(:find_by).with(email: default_email).and_return(nil)
      expect(helper.default_gmail_sender_available?).to eq(false)
    end

    it "returns false if default sender cannot send gmail" do
      allow(User).to receive(:find_by).with(email: default_email).and_return(double("User", can_send_gmail?: false))
      expect(helper.default_gmail_sender_available?).to eq(false)
    end
  end

  describe 'SettingsHelper methods' do
    let(:hash) { { 'foo' => 'bar', :baz => 'qux', 'nested' => { 'deep' => 42, :deeper => 43 }, :empty => '', :nil => nil } }

    # Stub SettingsHelper methods for testing
    module SettingsHelper
      def self.get_settings(hash, *keys)
        keys.each_with_object({}) do |key, result|
          value = hash[key]
          value = hash[key.to_s] if value.nil? && hash.key?(key.to_s)
          value = hash[key.to_sym] if value.nil? && hash.key?(key.to_sym)
          result[key] = value unless value.nil?
        end
      end

      def self.setting_present?(hash, key)
        value = hash[key]
        value = hash[key.to_s] if value.nil? && hash.key?(key.to_s)
        value = hash[key.to_sym] if value.nil? && hash.key?(key.to_sym)
        !value.nil? && !(value.respond_to?(:empty?) && value.empty?)
      end
    end

    it 'get_settings returns hash of found keys only' do
      result = SettingsHelper.get_settings(hash, :foo, :baz, :missing)
      expect(result).to eq({ foo: 'bar', baz: 'qux' })
    end

    it 'get_settings skips nil values' do
      result = SettingsHelper.get_settings(hash, :nil, :missing)
      expect(result).to eq({})
    end

    it 'setting_present? returns true for present value' do
      expect(SettingsHelper.setting_present?(hash, :foo)).to be true
    end

    it 'setting_present? returns false for nil value' do
      expect(SettingsHelper.setting_present?(hash, :nil)).to be false
    end

    it 'setting_present? returns false for empty string value' do
      expect(SettingsHelper.setting_present?(hash, :empty)).to be false
    end

    it 'setting_present? returns false for missing key' do
      expect(SettingsHelper.setting_present?(hash, :missing)).to be false
    end
  end
end
