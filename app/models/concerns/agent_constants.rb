##
# AgentConstants
#
# Centralized constants for agent names and statuses to avoid magic strings
# throughout the codebase.
#
module AgentConstants
  # Agent types
  AGENT_SEARCH = "SEARCH"
  AGENT_WRITER = "WRITER"
  AGENT_CRITIQUE = "CRITIQUE"
  AGENT_DESIGN = "DESIGN"
  AGENT_DESIGNER = "DESIGNER"
  AGENT_SENDER = "SENDER"

  # All valid agent names
  VALID_AGENT_NAMES = [
    AGENT_SEARCH,
    AGENT_WRITER,
    AGENT_CRITIQUE,
    AGENT_DESIGN,
    AGENT_DESIGNER,
    AGENT_SENDER
  ].freeze

  # Agent execution order
  AGENT_ORDER = [
    AGENT_SEARCH,
    AGENT_WRITER,
    AGENT_CRITIQUE,
    AGENT_DESIGN,
    AGENT_SENDER
  ].freeze

  # Agent output statuses
  STATUS_PENDING = "pending"
  STATUS_COMPLETED = "completed"
  STATUS_FAILED = "failed"

  # All valid statuses
  VALID_STATUSES = [
    STATUS_PENDING,
    STATUS_COMPLETED,
    STATUS_FAILED
  ].freeze

  # Lead stages (for stage progression)
  STAGE_QUEUED = "queued"
  STAGE_SEARCHED = "searched"
  STAGE_WRITTEN = "written"
  STAGE_CRITIQUED = "critiqued"
  STAGE_DESIGNED = "designed"
  STAGE_COMPLETED = "completed"
  STAGE_SENT_PREFIX = "sent" # Base prefix for sent stages (sent (1), sent (2), etc.)
  STAGE_SEND_FAILED = "send_failed" # Stage when email sending permanently fails
  STAGE_REWRITTEN_PREFIX = "rewritten" # Base prefix for rewritten stages

  # Stage progression order
  STAGE_PROGRESSION = [
    STAGE_QUEUED,
    STAGE_SEARCHED,
    STAGE_WRITTEN,
    STAGE_CRITIQUED,
    STAGE_DESIGNED,
    STAGE_COMPLETED
  ].freeze

  ##
  # Generates a rewritten stage name with count
  # @param count [Integer] The rewrite count (1, 2, 3, etc.)
  # @return [String] Stage name like "rewritten (1)", "rewritten (2)", etc.
  def self.rewritten_stage_name(count)
    "#{STAGE_REWRITTEN_PREFIX} (#{count})"
  end

  ##
  # Checks if a stage is a rewritten stage
  # @param stage [String] The stage to check
  # @return [Boolean] true if stage starts with "rewritten"
  def self.rewritten_stage?(stage)
    stage.to_s.start_with?(STAGE_REWRITTEN_PREFIX)
  end

  ##
  # Extracts rewrite count from a rewritten stage name
  # @param stage [String] The stage name (e.g., "rewritten (2)")
  # @return [Integer, nil] The rewrite count, or nil if not a rewritten stage
  def self.extract_rewrite_count(stage)
    return nil unless rewritten_stage?(stage)

    match = stage.match(/rewritten\s*\((\d+)\)/)
    match ? match[1].to_i : nil
  end
end
