require "spec_helper"
require "open3"
require_relative "../app/services/spam_classifier_wrapper"

RSpec.describe SpamClassifierWrapper do
  let(:email) { "This is a test email." }

  describe ".classify (class method)" do
    context "when Python script succeeds" do
      before do
        allow(Open3).to receive(:capture3)
          .with("python3", "-c", kind_of(String), email)
          .and_return(["0.12\n", "", instance_double(Process::Status, success?: true)])
      end

      it "returns the spam score as float" do
        score = described_class.classify(email)
        expect(score).to eq(0.12)
      end
    end

    context "when Python script fails" do
      before do
        allow(Open3).to receive(:capture3)
          .with("python3", "-c", kind_of(String), email)
          .and_return(["", "Some Python error", instance_double(Process::Status, success?: false)])
      end

      it "logs the error and returns nil" do
        expect { score = described_class.classify(email) }
          .to output(/Python error: Some Python error/).to_stderr
        expect(described_class.classify(email)).to be_nil
      end
    end

    context "when email is empty" do
      let(:email) { "" }

      before do
        allow(Open3).to receive(:capture3)
          .with("python3", "-c", kind_of(String), email)
          .and_return(["0.0\n", "", instance_double(Process::Status, success?: true)])
      end

      it "returns 0.0" do
        expect(described_class.classify(email)).to eq(0.0)
      end
    end
  end

  describe "#classify (instance method)" do
    let(:instance) { described_class.new }

    it "delegates to the class method" do
      expect(described_class).to receive(:classify).with(email).and_return(0.25)
      expect(instance.classify(email)).to eq(0.25)
    end
  end
end
