require 'rails_helper'

RSpec.describe Agents::SearchAgent, type: :service do
  let(:tavily_key) { "test-tavily-key" }
  let(:gemini_key) { "test-gemini-key" }
  let(:agent) { described_class.new(tavily_key: tavily_key, gemini_key: gemini_key) }

  describe "#initialize" do
    it "initializes with valid keys" do
      expect(agent).to be_a(described_class)
    end

    it "raises if tavily key missing" do
      expect { described_class.new(tavily_key: "", gemini_key: gemini_key) }
        .to raise_error(ArgumentError, "Tavily API key is required")
    end

    it "raises if gemini key missing" do
      expect { described_class.new(tavily_key: tavily_key, gemini_key: nil) }
        .to raise_error(ArgumentError, "Gemini API key is required")
    end
  end

  describe "#run" do
    let(:mock_gemini_response) do
      {
        "candidates" => [
          { "content" => { "parts" => [ { "text" => '["AI Safety", "Scaling", "Partnerships"]' } ] } }
        ]
      }
    end

    let(:mock_recipient_results_raw) do
      [
        { "title" => "Profile", "url" => "https://example.com", "content" => "Bio" }
      ]
    end

    let(:mock_company_results_raw) do
      [ { "title" => "Company News", "url" => "https://example-news.com", "content" => "Update" } ]
    end

    let(:mock_recipient_results) do
      [
        { title: "Profile", url: "https://example.com", content: "Bio" }
      ]
    end

    let(:mock_company_results) do
      [ { title: "Company News", url: "https://example-news.com", content: "Update" } ]
    end



    before do
      allow(HTTParty).to receive(:post)
        .with(/generativelanguage/, anything)
        .and_return(double(parsed_response: mock_gemini_response))

      allow(described_class).to receive(:post)
        .with("/search", anything)
        .and_return(
          double(success?: true, parsed_response: { "results" => mock_recipient_results_raw }),
          double(success?: true, parsed_response: { "results" => mock_company_results_raw })
        )
    end

    it "returns structured personalization data" do
      result = agent.run(
        company: "OpenAI",
        recipient_name: "Sam Altman",
        job_title: "CEO",
        email: "sam@openai.com"
      )

      expect(result[:target_identity][:name]).to eq("Sam Altman")
      expect(result[:inferred_focus_areas]).to eq([ "AI Safety", "Scaling", "Partnerships" ])
      expect(result[:personalization_signals][:recipient]).to eq(mock_recipient_results)
      expect(result[:personalization_signals][:company]).to eq(mock_company_results)
    end

    it "logs and returns empty inferred_focus_areas when Gemini returns invalid JSON" do
      allow(HTTParty).to receive(:post)
        .with(/generativelanguage/, anything)
        .and_return(double(parsed_response: { "candidates" => [ { "content" => { "parts" => [ { "text" => 'not-a-json' } ] } } ] }))

      logger = double("logger")
      allow(logger).to receive(:info)
      expect(logger).to receive(:error).with(/Gemini inference failed:/)
          agent.instance_variable_set(:@logger, logger)

      result = agent.run(company: "ABC", recipient_name: "DEF HIJ", job_title: "CEO", email: "defhij@abc.com")
      expect(result[:inferred_focus_areas]).to eq([])
    end
  end

  describe "#run_tavily_search" do
    let(:response) do
      { "results" => [ { "title" => "News", "url" => nil, "content" => nil } ] }
    end

    before do
      allow(described_class).to receive(:post)
        .and_return(double(success?: true, parsed_response: response))
    end

    it "returns mapped results" do
      expect(agent.send(:run_tavily_search, "query")).to eq([
        { title: "News", url: nil, content: nil }
      ])
    end

    it "returns empty array and logs an error when parsing fails" do
      allow(described_class).to receive(:post).and_return(double(success?: true, parsed_response: nil))

      logger = double("logger")
      expect(logger).to receive(:error).with(/Tavily batch search failed:/)
      agent.instance_variable_set(:@logger, logger)

      expect(agent.send(:run_tavily_search, "bad-query")).to eq([])
    end
  end
end
