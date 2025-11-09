require_relative "search_agent"
require_relative "writer_agent"
require_relative "critique_agent"

=begin
ORCHESTRATOR

OVERVIEW:
The Orchestrator coordinates the multi-agent pipeline to generate personalized B2B marketing emails
for target companies. It manages the flow from company name input → research → email generation → quality check.

WORKFLOW:
1. Takes company name and optional recipient as input
2. Calls SearchAgent to gather real-time news about the target company
3. Calls WriterAgent to generate personalized B2B email based on research
4. Calls CritiqueAgent to review email quality and effectiveness
5. Returns finalized email with critique and sources

DATA FLOW:
Input: company_name (e.g., "Microsoft"), recipient (optional, e.g., "John Doe")
  ↓
SearchAgent.run(company_name) → {company: "Microsoft", sources: [...], image: "..."}
  ↓
WriterAgent.run(search_results, recipient, company) → {company: "Microsoft", email: "Subject: ...", ...}
  ↓
CritiqueAgent.run(writer_output) → {critique: "..."}
  ↓
Output: {company, recipient, email, critique, sources}

KEY METHODS:
- initialize: Sets up SearchAgent, WriterAgent, and CritiqueAgent instances
- run(company_name, recipient: nil, product_info: nil, sender_company: nil): Executes the full pipeline
  - Calls SearchAgent to research the target company
  - Calls WriterAgent to generate personalized email TO that company (includes product/sender context)
  - Calls CritiqueAgent to ensure email quality
  - Returns complete email campaign with sources, critique, and context
=end

class Orchestrator
  def initialize(
    gemini_api_key: ENV.fetch("GEMINI_API_KEY"),
    tavily_api_key: ENV.fetch("TAVILY_API_KEY"),
    search_agent: nil,
    writer_agent: nil,
    critique_agent: nil
  )
    @search_agent = search_agent || SearchAgent.new(api_key: tavily_api_key)
    @writer_agent = writer_agent || WriterAgent.new(api_key: gemini_api_key)
    @critique_agent = critique_agent || CritiqueAgent.new(api_key: gemini_api_key)
  end

  def run(company_name, recipient: nil, product_info: nil, sender_company: nil)
    puts "\n" + "=" * 80
    puts "Starting pipeline"
    puts "=" * 80 + "\n"
    puts "Target Company: #{company_name}"
    puts "Recipient: #{recipient || 'General'}"
    puts "Your Company: #{sender_company || 'Not specified'}"
    puts

    # Step 1: Search for information about the company
    puts "Step 1: Searching for latest news about #{company_name} and #{recipient || 'General'}..."
    search_results = @search_agent.run(company_name, recipient: recipient)
    sources = Array(search_results[:sources])
    puts "Found #{sources.length} sources"

    # Step 2: Generate personalized email TO the company
    puts "Step 2: Generating personalized B2B outreach email..."
    writer_output = @writer_agent.run(
      search_results,
      recipient: recipient,
      company: company_name,
      product_info: product_info,
      sender_company: sender_company
    )
    email_text = writer_output[:email] || ""
    puts "Initial Email generated (#{email_text.length} characters)"

    # Step 3: Critique and revise until approved
    puts "Step 3: Running critique and revision loop..."
    revision_count = 0
    critique_result = nil

    loop do
      revision_count += 1
      puts "Revision attempt ##{revision_count}..."

      critique_input = {
        "email_content" => email_text,
        "number_of_revisions" => revision_count
      }

      critique_result = @critique_agent.run(critique_input)
      critique_text = critique_result["critique"]

      if critique_text.nil?
        puts "CritiqueAgent: Email approved ✅"
        break
      else
        puts "CritiqueAgent Feedback: #{critique_text[0..120]}..."
        break
      end
    end

    puts "\n" + "=" * 80
    puts "Pipeline completed successfully!"
    puts "=" * 80 + "\n"

    {
      company: company_name,
      recipient: recipient,
      email: email_text,
      critique: critique_result["critique"],
      sources: sources,
      product_info: product_info,
      sender_company: sender_company
    }
  end

  def self.run(company_name, gemini_api_key: ENV.fetch("GEMINI_API_KEY"), tavily_api_key: ENV.fetch("TAVILY_API_KEY"), recipient: nil, product_info: nil, sender_company: nil)
    new(gemini_api_key: gemini_api_key, tavily_api_key: tavily_api_key).run(
      company_name,
      recipient: recipient,
      product_info: product_info,
      sender_company: sender_company
    )
  end
end
