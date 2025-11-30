class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]

  has_many :campaigns, dependent: :destroy

  def self.from_google_omniauth(auth)
    # Try to find by provider + uid first
    user = find_by(provider: auth.provider, uid: auth.uid)

    if user
      return user
    end

    # If no provider/uid match, try to match by email (so Google login
    # attaches to an existing email/password user)
    user = find_or_initialize_by(email: auth.info.email)

    user.provider ||= auth.provider
    user.uid      ||= auth.uid
    user.password ||= Devise.friendly_token[0, 20]

    # Extract first_name and last_name from Google OAuth data
    if auth.info.first_name.present?
      user.first_name ||= auth.info.first_name
    elsif auth.info.name.present?
      # Fallback: try to split full name if first_name not available
      name_parts = auth.info.name.split(" ", 2)
      user.first_name ||= name_parts[0] if name_parts[0].present?
      user.last_name ||= name_parts[1] if name_parts[1].present?
    end

    if auth.info.last_name.present?
      user.last_name ||= auth.info.last_name
    end

    # Do NOT require workspace_name/job_title here
    user.save!
    user
  end

  def profile_complete?
    workspace_name.present? && job_title.present?
  end

  def gmail_connected?
    gmail_refresh_token.present?
  end

  def gmail_token_expired?
    gmail_token_expires_at.present? && Time.current >= gmail_token_expires_at
  end

  def can_send_gmail?
    gmail_access_token.present? && gmail_email.present?
  end

  def send_gmail!(to:, subject:, text_body:, html_body: nil)
    raise "User has not connected Gmail" unless can_send_gmail?

    GmailSender.send_email(
      user: self,
      to: to,
      subject: subject,
      text_body: text_body,
      html_body: html_body
    )
  end

  def self.serialize_from_session(*args)
    super(*args.take(2))
  end
end
