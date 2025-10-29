class Campaign < ApplicationRecord
  belongs_to :user
  has_many :leads, dependent: :destroy
  has_many :agent_configs, dependent: :destroy

  validates :title, presence: true
  validates :base_prompt, presence: true

  # Map camelCase API attribute to snake_case database column
  def basePrompt
    base_prompt
  end

  def basePrompt=(value)
    self.base_prompt = value
  end

  # Override as_json to maintain API compatibility with camelCase
  def as_json(options = {})
    super(options).merge(
      'basePrompt' => base_prompt
    ).except('base_prompt')
  end
end


