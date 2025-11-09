# CampAIgn - AI-Powered Campaign Management Platform
- Konstantinos Anagnostopoulos (ka3037)
- Riz Chen (sc5144)
- Siying Ding (sd3609)
- Aarushi Sharma (as6322)

A modern SaaS application for managing AI-powered marketing campaigns with intelligent agent workflows. Built with Ruby on Rails and React, featuring automated lead processing through AI agents.

## Team members

- Konstantinos Anagnostopulos (ka3037)
- Riz Chen (sc5144)
- Siying Ding (sd3609)
- Aarushi Sharma (as6322)

## 🎯 Project Overview

CampAIgn is a comprehensive campaign management platform that automates the entire lead processing pipeline using AI agents. Users can create campaigns, add leads, and let the AI system automatically research companies, generate personalized emails, and provide quality feedback.

### AI Agent Pipeline
1. **Search Agent** - Researches target companies using Tavily API for real-time news and information
2. **Writer Agent** - Generates personalized B2B outreach emails using Google Gemini API
3. **Design Agent** - Applies markdown formatting (bold, italic, links, etc.) to email content
4. **Critique Agent** - Reviews email quality and provides improvement suggestions
5. **Email Sender** - Sends formatted emails to leads after processing is complete
6. **Orchestrator** - Coordinates the entire pipeline and manages agent execution

### User Workflow
1. **Create Campaign** - Set up campaign with base prompts and agent configurations
2. **Add Leads** - Import or manually add lead information (name, email, company, title)
3. **Run Agents** - Execute AI agents to process leads automatically (SEARCH → WRITER → DESIGN → CRITIQUE)
4. **Review Outputs** - View and edit agent-generated content through the UI
5. **Track Progress** - Monitor lead processing status and quality metrics
6. **Send Emails** - Send formatted emails to ready leads with a single click

## 📁 Codebase Structure

```
web/                          # Root directory (Rails application)
├── app/
│   ├── controllers/           # MVC controllers
│   │   └── api/v1/           # RESTful API endpoints
│   ├── models/                # ActiveRecord models
│   │   ├── user.rb           # User authentication
│   │   ├── campaign.rb       # Campaign management
│   │   ├── lead.rb           # Lead information
│   │   ├── agent_config.rb   # Agent configurations
│   │   └── agent_output.rb   # Agent execution results
│   ├── services/              # Business logic
│   │   ├── orchestrator.rb   # Agent pipeline coordinator
│   │   ├── search_agent.rb   # Company research agent
│   │   ├── writer_agent.rb   # Email generation agent
│   │   ├── design_agent.rb   # Email formatting agent
│   │   ├── critique_agent.rb # Quality review agent
│   │   ├── lead_agent_service.rb # Lead processing service
│   │   └── email_sender_service.rb # Email sending service
│   ├── mailers/               # Email templates
│   │   └── campaign_mailer.rb # Campaign email mailer
│   ├── javascript/            # React/TypeScript frontend
│   │   ├── components/        # React components
│   │   ├── hooks/             # Custom React hooks
│   │   ├── libs/              # Utilities and API client
│   │   └── types/             # TypeScript definitions
│   └── views/                 # ERB templates
├── config/                    # Rails configuration
├── db/                        # Database migrations and seeds
├── spec/                      # RSpec test suite (178 tests)
├── public/                    # Static assets
├── package.json               # Node.js dependencies
├── tsconfig.json              # TypeScript configuration
├── tailwind.config.js         # Tailwind CSS configuration
└── README.md                  # This file
```

## 🚀 How to Run This Application

### Prerequisites

- **Ruby:** 3.3.9+ 
- **Rails:** 8.1
- **PostgreSQL:** 12+
- **Node.js:** 16.x (required for Webpacker compatibility)
- **Yarn:** 1.22.x

### Installation

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd web
   ```

2. **Install dependencies**
   ```bash
   # Install Ruby gems
   bundle install
   
   # Install Node.js packages
   yarn install
   ```

3. **Setup database**
   ```bash
   # Create databases
   rails db:create
   
   # Run migrations
   rails db:migrate
   
   # Seed initial data
   rails db:seed
   ```

4. **Start the application**
   ```bash
   # Start Rails server (http://localhost:3000)
   rails server
   
   # In another terminal, start Webpack dev server (for hot reload)
   ./bin/webpack-dev-server
   ```

5. **Access the application**
   - Open [http://localhost:3000](http://localhost:3000)
   - **Development Mode**: You're automatically logged in as `admin@example.com`
   - Create your first campaign
   - Add leads and run the AI agents

### Environment Variables

Create a `.env` file in the root directory:

```bash
# Database
POSTGRES_PASSWORD=your_password
RAILS_MAX_THREADS=5

# API Keys (for AI agents)
GEMINI_API_KEY=your_gemini_api_key
TAVILY_API_KEY=your_tavily_api_key

# Email Configuration
# Required: Sender email address
MAILER_FROM="noreply@yourdomain.com"

# Required: Mail server domain (for links in emails)
MAILER_HOST="yourdomain.com"

# SMTP Configuration (required to actually send emails)
# For Gmail, see "Gmail Setup" section below
SMTP_ADDRESS="smtp.gmail.com"
SMTP_PORT="587"
SMTP_USER_NAME="your-email@gmail.com"
SMTP_PASSWORD="your-app-password"  # For Gmail: use app-specific password
SMTP_DOMAIN="gmail.com"
SMTP_AUTHENTICATION="plain"
SMTP_ENABLE_STARTTLS="true"

# Optional: Disable authentication in development (default: true)
# In development mode, you're automatically logged in as admin@example.com
DISABLE_AUTH=true
```

**Note**: The `.env` file is automatically loaded by `dotenv-rails` gem. After creating or modifying `.env`, **restart your Rails server** for changes to take effect.

## 🛠️ Development Mode

In development mode, the application automatically:
- **Disables authentication** - No need to register or login
- **Creates admin user** - Automatically logs you in as `admin@example.com`
- **Uses default password** - `password123` (if you need to login manually)
- **Auto-creates user** - The admin user is created automatically on first access
- *** Note: Click on the user profile to add the following API keys (setup just for mvp as a backup)
  ```
  LLM_API_KEY=AIzaSyCtqoCmJ9r5zxSSYu27Kxffa5HaXDrlKvE
  TAVILY_API_KEY=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
  ```

This makes it easy for anyone to clone and run the application without any setup.

## 🔧 Available Scripts

```bash
# Database
rails db:create              # Create databases
rails db:migrate             # Run migrations
rails db:seed                # Seed database
rails db:rollback            # Rollback last migration

# Development
rails server                 # Start Rails server
./bin/webpack-dev-server     # Start Webpack dev server
rails console                # Open Rails console

# Testing
bundle exec rspec            # Run RSpec tests (178 tests)
yarn test                    # Run Jest tests (106 tests)
yarn test:coverage           # Run tests with coverage
```

## 🎯 Key Features

- **Campaign Management** - Create and manage marketing campaigns
- **Lead Processing** - Add and track leads with automated AI processing
- **AI Agent System** - Automated research, writing, design formatting, and critique
- **Email Sending** - Send formatted emails to leads with markdown support (bold, italic, links, etc.)
- **User Authentication** - Secure user registration and login
- **API Management** - RESTful API for all operations
- **Responsive Design** - Mobile-first UI with Tailwind CSS
- **Real-time Updates** - Live progress tracking and status updates

## 🔐 Security

- CSRF protection enabled
- User authentication with Devise
- Rate limiting with Rack::Attack
- Content Security Policy (CSP)
- User-scoped data access
- SSL enforced in production

## 📊 Testing

- **178 RSpec tests** - 90%+ line coverage
![Rspec Coverage](./rspec_coverage.png)
- **106 Jest tests** - 96.6% coverage
- Integration tests for complete workflows
- Component tests for UI elements
- API endpoint testing

## User Stories in Cucumber
![Cucumber Pass](./cucumber_pass.png)
The Cucumber suite validates the app from a user’s perspective across UI and API. It confirms authenticated access to the dashboard (including empty state and React mount), basic layout integrity (title, meta, icons, pack tags), and full campaign/lead workflows: listing, creating, updating, and deleting resources restricted to the owner. It checks input validation (e.g., missing titles/emails) and authorization boundaries (preventing edits to others’ campaigns). For agent workflows, it verifies error handling when running agents on nonexistent leads, retrieving agent outputs for a lead, and updating outputs for WRITER and SEARCH. It also ensures API keys can be stored and read from session. Together, these scenarios cover the core journeys—UI access, data CRUD, guardrails (auth/validation), and integrations—with all tests passing.

## 📧 Email Configuration

The application includes an email sending feature that allows you to send formatted emails to leads after they've been processed by the AI agents.

### Setting Up Email in .env File

#### Step 1: Create .env File

Create a `.env` file in the project root directory (if it doesn't exist):

```bash
touch .env
```

#### Step 2: Add Email Configuration

Add the following to your `.env` file:

```bash
# Required: Sender email address
MAILER_FROM="your-email@gmail.com"

# Required: Mail server domain (for links in emails)
MAILER_HOST="localhost"  # Use your domain in production

# SMTP Configuration (required to actually send emails)
SMTP_ADDRESS="smtp.gmail.com"
SMTP_PORT="587"
SMTP_USER_NAME="your-email@gmail.com"
SMTP_PASSWORD="your-app-password"  # See Gmail setup below
SMTP_DOMAIN="gmail.com"
SMTP_AUTHENTICATION="plain"
SMTP_ENABLE_STARTTLS="true"
```

#### Step 3: Restart Rails Server

**Important**: After creating or modifying `.env`, you must restart your Rails server:

```bash
# Stop the server (Ctrl+C)
# Then restart:
rails server
```

### Gmail Setup

To use Gmail for sending emails, you need to generate an **App-Specific Password**:

#### 1. Enable Two-Factor Authentication

1. Go to [Google Account Security](https://myaccount.google.com/security)
2. Enable **2-Step Verification** (if not already enabled)

#### 2. Generate App-Specific Password

1. Visit [Google App Passwords](https://myaccount.google.com/apppasswords)
2. Select **Mail** as the app
3. Select **Other (Custom name)** as the device, enter "Campaign SaaS"
4. Click **Generate**
5. **Copy the 16-character password** (remove spaces when using it)

#### 3. Add to .env File

Add the app-specific password to your `.env` file:

```bash
SMTP_USER_NAME="your-email@gmail.com"
SMTP_PASSWORD="your-16-character-app-password"  # No spaces
```

**Important**: 
- Use the **app-specific password**, not your regular Gmail password
- The password should be 16 characters with no spaces
- Keep this password secure and never commit it to Git

### Development Environment Modes

The development environment supports three modes:

**Mode 1: File Storage (Default)**
- Don't set `SMTP_ADDRESS` in `.env`
- Emails are saved to `tmp/mail` directory
- Emails are not actually sent
- Useful for development without sending real emails

**Mode 2: Test Mode**
Add to `.env`:
```bash
MAIL_DELIVERY_METHOD="test"
```
- Emails are stored in `ActionMailer::Base.deliveries` array
- Useful for automated testing

**Mode 3: Real Sending (Gmail)**
- Set all SMTP variables in `.env` (as shown above)
- Emails will actually be sent through Gmail SMTP
- **Remember to restart Rails server after updating `.env`**

### Production Environment

In production, **you must configure SMTP** to send emails. Set these as environment variables in your hosting platform (e.g., Heroku Config Vars):

```bash
SMTP_ADDRESS="smtp.your-provider.com"
SMTP_PORT="587"
SMTP_USER_NAME="your-username"
SMTP_PASSWORD="your-password"
MAILER_FROM="noreply@yourdomain.com"
MAILER_HOST="yourdomain.com"
```

**For Heroku**:
```bash
heroku config:set SMTP_ADDRESS="smtp.gmail.com"
heroku config:set SMTP_PORT="587"
heroku config:set SMTP_USER_NAME="your-email@gmail.com"
heroku config:set SMTP_PASSWORD="your-app-password"
heroku config:set MAILER_FROM="your-email@gmail.com"
heroku config:set MAILER_HOST="yourdomain.com"
```

If SMTP is not configured, emails will be saved to `tmp/mail` directory (not recommended for production).

### Common Email Provider Configurations

#### Gmail

```bash
export SMTP_ADDRESS="smtp.gmail.com"
export SMTP_PORT="587"
export SMTP_USER_NAME="your-email@gmail.com"
export SMTP_PASSWORD="your-app-password"  # Must use app-specific password
export SMTP_DOMAIN="gmail.com"
export SMTP_AUTHENTICATION="plain"
export SMTP_ENABLE_STARTTLS="true"
```

**Note**: Gmail requires an [app-specific password](https://support.google.com/accounts/answer/185833), not your regular password.

#### SendGrid

```bash
export SMTP_ADDRESS="smtp.sendgrid.net"
export SMTP_PORT="587"
export SMTP_USER_NAME="apikey"
export SMTP_PASSWORD="your-sendgrid-api-key"
export SMTP_DOMAIN="yourdomain.com"
export SMTP_AUTHENTICATION="plain"
export SMTP_ENABLE_STARTTLS="true"
```

#### Mailgun

```bash
export SMTP_ADDRESS="smtp.mailgun.org"
export SMTP_PORT="587"
export SMTP_USER_NAME="your-mailgun-username"
export SMTP_PASSWORD="your-mailgun-password"
export SMTP_DOMAIN="yourdomain.com"
export SMTP_AUTHENTICATION="plain"
export SMTP_ENABLE_STARTTLS="true"
```

#### AWS SES

```bash
export SMTP_ADDRESS="email-smtp.us-east-1.amazonaws.com"  # Adjust for your region
export SMTP_PORT="587"
export SMTP_USER_NAME="your-aws-ses-smtp-username"
export SMTP_PASSWORD="your-aws-ses-smtp-password"
export SMTP_DOMAIN="yourdomain.com"
export SMTP_AUTHENTICATION="plain"
export SMTP_ENABLE_STARTTLS="true"
```

### Email Sending Conditions

Only leads that meet the following conditions will have their emails sent:

1. **Stage Status**: The lead's `stage` must be `'critiqued'` or `'completed'`
2. **Email Content**: The lead must have a completed DESIGN agent output (preferred) or WRITER agent output (fallback)

### Viewing Sent Emails

**Development Environment (File Mode)**
- Emails are saved in: `tmp/mail/` directory, each email is a file

**Development Environment (Test Mode)**
- View in Rails console:
  ```ruby
  ActionMailer::Base.deliveries
  ```

**Production Environment**
- Emails are actually sent to recipients' email addresses

### Verifying Email Configuration

To check if your email configuration is working:

1. **Check Rails logs** when clicking "Send":
   - **Success (SMTP)**: `Delivered mail to recipient@email.com (xxxms)`
   - **File mode**: `Delivered mail [random-filename]@localhost.mail`

2. **Verify configuration**:
   ```bash
   rails runner "puts Rails.application.config.action_mailer.delivery_method"
   # Should return: smtp
   ```

3. **Test in Rails console**:
   ```ruby
   require_relative 'app/mailers/campaign_mailer'
   CampaignMailer.send_email(
     to: "your-test-email@gmail.com",
     recipient_name: "Test",
     email_content: "Subject: Test\n\nTest email",
     campaign_title: "Test Campaign"
   ).deliver_now
   ```

### Troubleshooting

1. **Emails not sending / Still in file mode**:
   - ✅ Check if `.env` file exists in project root
   - ✅ Verify `SMTP_ADDRESS` is set in `.env`
   - ✅ **Restart Rails server** after modifying `.env`
   - ✅ Check if `dotenv-rails` gem is installed: `bundle list | grep dotenv`
   - ✅ Verify environment variables are loaded: `rails runner "puts ENV['SMTP_ADDRESS']"`

2. **SMTP authentication failed**:
   - For Gmail: Ensure you're using an **app-specific password**, not your regular password
   - Verify the password is 16 characters with no spaces
   - Regenerate app-specific password if needed: https://myaccount.google.com/apppasswords

3. **SSL certificate error**:
   - Already handled in development environment (SSL verification disabled)
   - In production, ensure your SMTP provider's SSL certificates are valid

4. **Emails going to spam**:
   - Check spam/junk folder
   - Configure SPF, DKIM, and DMARC records for your domain
   - Consider using professional email services (SendGrid, Mailgun) for production
   - Ensure sender address is from a verified domain

## 🚀 Deployment

### Live Application
The application is currently deployed and running on Heroku:
**🌐 https://campaign-saas-7460a258bf90.herokuapp.com/**

### Production Features
- **Heroku PostgreSQL** - Managed database with automatic backups
- **Redis** - Caching and rate limiting
- **Asset Pipeline** - Optimized CSS and JavaScript compilation
- **SSL/HTTPS** - Secure connections enforced
- **Environment Variables** - Secure API key management
- **Comprehensive Error Handling** - Production-ready error management
- **Security Best Practices** - CSRF protection, rate limiting, and more

### Deployment Configuration
- **Node.js 16.x** - Pinned for Webpacker compatibility
- **Ruby 3.3.9** - Latest stable Ruby version
- **PostgreSQL** - Essential-0 plan on Heroku
- **Buildpacks** - Node.js and Ruby buildpacks configured
- **Asset Precompilation** - Optimized for production performance

## 📝 API Documentation

API endpoints are available at `/api/v1/`:

- `GET/POST/PUT/DELETE /api/v1/campaigns` - Campaign management
- `POST /api/v1/campaigns/:id/send_emails` - Send emails to all ready leads in a campaign
- `GET/POST/PUT/DELETE /api/v1/leads` - Lead management
- `GET/POST/PUT/DELETE /api/v1/campaigns/:id/agent_configs` - Agent configuration
- `POST /api/v1/leads/:id/run_agents` - Execute AI agents
- `GET /api/v1/leads/:id/agent_outputs` - Retrieve agent outputs
- `PATCH /api/v1/leads/:id/update_agent_output` - Update agent output (WRITER, SEARCH, DESIGN)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License.

---

**Built with ❤️ using Rails, React, TypeScript, and Tailwind CSS**
