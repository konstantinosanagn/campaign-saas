module AgentExecution
  ENV_PAUSED_FLAG = "AGENT_EXECUTION_PAUSED".freeze

  class ExecutionPausedError < StandardError; end

  def self.paused?
    ENV.fetch(ENV_PAUSED_FLAG, "false") == "true"
  end
end
