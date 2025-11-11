require_relative "api_key_service"
require_relative "agents/search_agent"
require_relative "agents/writer_agent"
require_relative "agents/critique_agent"
require_relative "agents/design_agent"

##
# LeadAgentService
#
# Orchestrates the execution of agents (SEARCH → WRITER → CRITIQUE → DESIGN) for a specific lead.
# Manages agent configuration retrieval, sequential execution, output storage, and stage updates.
#
# Usage:
#   result = LeadAgentService.run_agents_for_lead(lead, campaign, user)
#   # Returns: { status: 'completed'|'partial'|'failed', outputs: {...}, lead: {...} }
#
class LeadAgentService
  include AgentConstants

  # Stage progression: queued → searched → written → critiqued → designed → completed
  # Each agent moves the lead to the next stage in the progression

  class << self
    ##
    # Runs the NEXT agent for a specific lead based on its current stage
    # Only runs ONE agent at a time to allow for human review between stages
    # @param lead [Lead] The lead to process
    # @param campaign [Campaign] The campaign containing agent configs
    # @param user [User] Current user containing API keys
    # @return [Hash] Result with status, outputs, and updated lead
    def run_agents_for_lead(lead, campaign, user)
      # Validate API keys before starting
      unless ApiKeyService.keys_available?(user)
        missing_keys = ApiKeyService.missing_keys(user)
        return {
          status: "failed",
          error: "Missing API keys: #{missing_keys.join(', ')}. Please add them in the API Keys section.",
          outputs: {},
          lead: lead
        }
      end

      # Check if lead is already at final stage
      next_agent = determine_next_agent(lead.stage)
      unless next_agent
        # Lead is already at final stage
        return {
          status: "completed",
          error: "Lead has already reached the final stage",
          outputs: {},
          lead: lead,
          completed_agents: [],
          failed_agents: []
        }
      end

      # Get API keys
      gemini_key = ApiKeyService.get_gemini_api_key(user)
      tavily_key = ApiKeyService.get_tavily_api_key(user)

      # Initialize agents
      search_agent = Agents::SearchAgent.new(api_key: tavily_key)
      writer_agent = Agents::WriterAgent.new(api_key: gemini_key)
      critique_agent = Agents::CritiqueAgent.new(api_key: gemini_key)
      design_agent = Agents::DesignAgent.new(api_key: gemini_key)

      # Track execution results
      outputs = {}
      completed_agents = []
      failed_agents = []

      # Run agents, skipping disabled ones and continuing to the next enabled agent
      # Stop after the first successful execution (or failure)
      max_iterations = 10 # Safety limit to prevent infinite loops
      iteration = 0
      agent_executed = false

      while iteration < max_iterations && !agent_executed
        iteration += 1

        # Determine which agent to run based on current stage
        next_agent = determine_next_agent(lead.stage)

        # If already at final stage, break
        unless next_agent
          break
        end

        # Get agent config for this campaign
        agent_config = get_agent_config(campaign, next_agent)

        # Skip if agent is disabled - advance stage and continue to next agent
        if agent_config&.disabled?
          # Still advance stage for disabled agents
          advance_stage(lead, next_agent)
          lead.reload
          # Continue to next agent without executing
          next
        end

        # Execute the agent (this is the first enabled agent we found)
        begin
          # Load previous outputs if needed
          previous_outputs = load_previous_outputs(lead, next_agent)

          # Execute agent based on type
          case next_agent
          when AgentConstants::AGENT_SEARCH
            result = execute_search_agent(search_agent, lead, agent_config)
          when AgentConstants::AGENT_WRITER
            result = execute_writer_agent(writer_agent, lead, agent_config, previous_outputs[AgentConstants::AGENT_SEARCH])
          when AgentConstants::AGENT_CRITIQUE
            result = execute_critique_agent(critique_agent, lead, agent_config, previous_outputs[AgentConstants::AGENT_WRITER])
          when AgentConstants::AGENT_DESIGN
            result = execute_design_agent(design_agent, lead, agent_config, previous_outputs[AgentConstants::AGENT_CRITIQUE])
          end

          # Store output
          save_agent_output(lead, next_agent, result, AgentConstants::STATUS_COMPLETED)
          outputs[next_agent] = result
          completed_agents << next_agent

          # Advance to next stage
          advance_stage(lead, next_agent)

          # Update lead quality if CRITIQUE completed successfully
          if next_agent == AgentConstants::AGENT_CRITIQUE && result
            update_lead_quality(lead, result)
          end

          # Mark that we've executed an agent and break
          agent_executed = true
          lead.reload

        rescue => e
          # Store error output with appropriate fields based on agent type
          error_output = { error: e.message, agent: next_agent }
          
          # Add agent-specific fields for error outputs
          case next_agent
          when AgentConstants::AGENT_WRITER
            error_output[:email] = ""
            error_output[:company] = lead.company
            error_output[:recipient] = lead.name
          when AgentConstants::AGENT_DESIGN
            error_output[:email] = ""
            error_output[:formatted_email] = ""
            error_output[:company] = lead.company
            error_output[:recipient] = lead.name
          when AgentConstants::AGENT_CRITIQUE
            error_output["critique"] = nil
            # error key already set above
          end
          
          save_agent_output(lead, next_agent, error_output, AgentConstants::STATUS_FAILED)
          outputs[next_agent] = error_output
          failed_agents << next_agent

          # DO NOT advance stage if agent failed
          # Lead stays at current stage for retry
          # Mark as executed and break
          agent_executed = true
        end
      end

      # Determine overall status
      status = determine_status(completed_agents, failed_agents)

      # Reload lead to get updated attributes
      lead.reload

      {
        status: status,
        outputs: outputs,
        lead: lead,
        completed_agents: completed_agents,
        failed_agents: failed_agents
      }
    end

    private

    ##
    # Determines which agent should run next based on current stage
    def determine_next_agent(current_stage)
      stage_index = AgentConstants::STAGE_PROGRESSION.index(current_stage)
      return nil if stage_index.nil? || stage_index >= AgentConstants::STAGE_PROGRESSION.length - 1

      # Map stage to next agent
      # queued -> SEARCH (to become 'searched')
      # searched -> WRITER (to become 'written')
      # written -> CRITIQUE (to become 'critiqued')
      # critiqued -> DESIGN (to become 'designed')
      # designed -> nil (final stage)
      case current_stage
      when AgentConstants::STAGE_QUEUED
        AgentConstants::AGENT_SEARCH
      when AgentConstants::STAGE_SEARCHED
        AgentConstants::AGENT_WRITER
      when AgentConstants::STAGE_WRITTEN
        AgentConstants::AGENT_CRITIQUE
      when AgentConstants::STAGE_CRITIQUED
        AgentConstants::AGENT_DESIGN
      else
        nil
      end
    end

    ##
    # Loads previous agent outputs that are needed for the current agent
    def load_previous_outputs(lead, current_agent)
      outputs = {}

      # WRITER needs SEARCH output
      if current_agent == AgentConstants::AGENT_WRITER
        search_output = lead.agent_outputs.find_by(agent_name: AgentConstants::AGENT_SEARCH)
        outputs[AgentConstants::AGENT_SEARCH] = search_output&.output_data
      end

      if current_agent == AgentConstants::AGENT_CRITIQUE
        writer_output = lead.agent_outputs.find_by(agent_name: AgentConstants::AGENT_WRITER)
        outputs[AgentConstants::AGENT_WRITER] = writer_output&.output_data
      end

      if current_agent == AgentConstants::AGENT_DESIGN
        critique_output = lead.agent_outputs.find_by(agent_name: AgentConstants::AGENT_CRITIQUE)
        outputs[AgentConstants::AGENT_CRITIQUE] = critique_output&.output_data
      end

      outputs
    end

    ##
    # Gets agent configuration for a campaign, creates default if not exists
    def get_agent_config(campaign, agent_name)
      campaign.agent_configs.find_by(agent_name: agent_name) ||
        campaign.agent_configs.create!(
          agent_name: agent_name,
          settings: default_settings_for_agent(agent_name),
          enabled: true  # Enabled by default to allow execution
        )
    end

    ##
    # Returns default settings for each agent type
    def default_settings_for_agent(agent_name)
      case agent_name
      when AgentConstants::AGENT_WRITER
        { product_info: "", sender_company: "" }
      when AgentConstants::AGENT_SEARCH, AgentConstants::AGENT_DESIGN, AgentConstants::AGENT_CRITIQUE
        {}
      else
        {}
      end
    end

    ##
    # Executes the SearchAgent
    def execute_search_agent(search_agent, lead, agent_config)
      # Extract domain from lead email or use company name
      domain = extract_domain_from_lead(lead)
      # Pass agent_config to search_agent so it can use settings
      config_hash = agent_config ? { settings: agent_config.settings } : nil
      search_agent.run(domain, recipient: lead.name, config: config_hash)
    end

    ##
    # Executes the WriterAgent
    def execute_writer_agent(writer_agent, lead, agent_config, search_output)
      # Prepare search results for writer
      # Convert string keys to symbols for consistency
      sources = search_output&.dig("sources") || search_output&.dig(:sources) || []
      image = search_output&.dig("image") || search_output&.dig(:image)

      # Deep symbolize keys for sources array
      symbolized_sources = sources.map do |source|
        source.is_a?(Hash) ? source.deep_symbolize_keys : source
      end

      search_results = {
        company: lead.company,
        sources: symbolized_sources,
        image: image
      }

      # Get writer settings from config
      settings = agent_config&.settings || {}

      # Get shared_settings from campaign (product_info and sender_company are now in shared_settings)
      shared_settings = lead.campaign.shared_settings || {}
      product_info = shared_settings["product_info"] || shared_settings[:product_info] || settings["product_info"]
      sender_company = shared_settings["sender_company"] || shared_settings[:sender_company] || settings["sender_company"]

      # Pass config and shared_settings to writer_agent
      config_hash = agent_config ? { settings: agent_config.settings } : nil
      writer_agent.run(
        search_results,
        recipient: lead.name,
        company: lead.company,
        product_info: product_info,
        sender_company: sender_company,
        config: config_hash,
        shared_settings: shared_settings
      )
    end

    ##
    # Executes the CritiqueAgent
    def execute_critique_agent(critique_agent, lead, agent_config, writer_output)
      # Prepare writer output for critique
      # Handle both string and symbol keys from JSONB storage
      email_content = writer_output&.dig("email") ||
                      writer_output&.dig(:email) ||
                      writer_output&.dig("formatted_email") ||
                      writer_output&.dig(:formatted_email) ||
                      ""

      # Get variants if they exist
      variants = writer_output&.dig("variants") || writer_output&.dig(:variants) || []

      article = {
        "email_content" => email_content,
        "variants" => variants,
        "number_of_revisions" => 0
      }

      # Pass config to critique_agent
      config_hash = agent_config ? { settings: agent_config.settings } : nil
      result = critique_agent.run(article, config: config_hash)

      # If a variant was selected, update the email content
      if result["selected_variant"]
        result["email"] = result["selected_variant"]
        result["email_content"] = result["selected_variant"]
      end

      result
    end

    ##
    # Executes the DesignAgent
    def execute_design_agent(design_agent, lead, agent_config, critique_output)
      # Prepare critique output for design
      # Prefer selected_variant if available, otherwise use email_content or email
      # Handle both string and symbol keys from JSONB storage
      email_content = critique_output&.dig("selected_variant") ||
                      critique_output&.dig(:selected_variant) ||
                      critique_output&.dig("email_content") ||
                      critique_output&.dig(:email_content) ||
                      critique_output&.dig("email") ||
                      critique_output&.dig(:email) ||
                      ""

      # Fallback to WRITER output if critique_output doesn't have email
      if email_content.blank?
        writer_output = lead.agent_outputs.find_by(agent_name: AgentConstants::AGENT_WRITER)
        if writer_output
          email_content = writer_output.output_data["email"] ||
                         writer_output.output_data[:email] ||
                         writer_output.output_data["formatted_email"] ||
                         writer_output.output_data[:formatted_email] ||
                         ""
        end
      end

      # Get company and recipient from lead
      company = lead.company
      recipient = lead.name

      # Prepare input hash for design agent
      design_input = {
        email: email_content,
        company: company,
        recipient: recipient
      }

      # Pass config to design_agent
      config_hash = agent_config ? { settings: agent_config.settings } : nil
      design_agent.run(design_input, config: config_hash)
    end

    ##
    # Extracts domain from lead email or falls back to company name
    def extract_domain_from_lead(lead)
      if lead.email.present?
        lead.email.split("@").last
      else
        lead.company
      end
    end

    ##
    # Saves agent output to the database
    def save_agent_output(lead, agent_name, output_data, status)
      agent_output = lead.agent_outputs.find_or_initialize_by(agent_name: agent_name)
      agent_output.assign_attributes(
        output_data: output_data,
        status: status,
        error_message: status == AgentConstants::STATUS_FAILED ? output_data[:error] : nil
      )
      agent_output.save!
    end

    ##
    # Advances lead to the next stage in the progression
    def advance_stage(lead, agent_name)
      current_index = AgentConstants::STAGE_PROGRESSION.index(lead.stage) || -1
      next_index = current_index + 1

      # Only advance if not already at the final stage
      if next_index < AgentConstants::STAGE_PROGRESSION.length
        new_stage = AgentConstants::STAGE_PROGRESSION[next_index]
        lead.update!(stage: new_stage)
      end
    end

    ##
    # Updates lead quality based on critique feedback
    def update_lead_quality(lead, critique_output)
      # Simple quality assessment based on critique presence
      # If critique is nil or empty, email was approved (high quality)
      # If critique exists, email needs improvement (medium quality)
      critique = critique_output.is_a?(Hash) ? critique_output["critique"] : nil
      quality = (critique.nil? || critique.empty?) ? "high" : "medium"

      if lead.quality != quality
        lead.update!(quality: quality)
      end
    end

    ##
    # Determines overall execution status
    def determine_status(completed_agents, failed_agents)
      if failed_agents.any?
        "failed"
      elsif completed_agents.any?
        "completed"  # Single agent completion is still 'completed'
      else
        "failed"
      end
    end
  end
end
