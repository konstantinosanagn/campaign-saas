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

  # All valid agent names
  VALID_AGENT_NAMES = [
    AGENT_SEARCH,
    AGENT_WRITER,
    AGENT_CRITIQUE,
    AGENT_DESIGN
  ].freeze

  # Agent execution order
  AGENT_ORDER = [
    AGENT_SEARCH,
    AGENT_WRITER,
    AGENT_CRITIQUE,
    AGENT_DESIGN
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

  # Stage progression order
  STAGE_PROGRESSION = [
    STAGE_QUEUED,
    STAGE_SEARCHED,
    STAGE_WRITTEN,
    STAGE_CRITIQUED,
    STAGE_DESIGNED,
    STAGE_COMPLETED
  ].freeze
end

