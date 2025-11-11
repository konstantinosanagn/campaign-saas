# CampAIgn - AI-Powered Campaign Management Platform

**Team:**
- Konstantinos Anagnostopoulos (ka3037)
- Riz Chen (sc5144)
- Siying Ding (sd3609)
- Aarushi Sharma (as6322)

A modern SaaS application for managing AI-powered marketing campaigns with intelligent agent workflows. Built with **Ruby on Rails 8.1**, **React 18**, **PostgreSQL**, and **TypeScript**.

## Prerequisites

- **Ruby:** 3.3.9+
- **Rails:** 8.1
- **PostgreSQL:** 12+
- **Node.js:** 16.x (required for Webpacker compatibility)
- **Yarn:** 1.22.x

## Installation

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd saas-proj
   ```

2. **Install dependencies**
   ```bash
   bundle install
   yarn install
   ```

3. **Setup database**
   ```bash
   rails db:create
   rails db:migrate
   rails db:seed
   ```

4. **Start the application**
   ```bash
   # Terminal 1: Rails server
   rails server
   
   # Terminal 2: Webpack dev server (for hot reload)
   ./bin/webpack-dev-server
   ```

5. **Access the application**
   - Open http://localhost:3000
   - You're automatically logged in as `admin@example.com`

## Development Mode

### Default User
- **Email:** `admin@example.com`
- **Password:** `password123`
- Auto-login enabled (no authentication required)

### Default API Keys
API keys are automatically populated for the admin user:
- **LLM_API_KEY:** `AIzaSyCtqoCmJ9r5zxSSYu27Kxffa5HaXDrlKvE`
- **TAVILY_API_KEY:** `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`

**Note:** Click on user profile to add/update API keys manually if needed.

### Authentication
- `DISABLE_AUTH` is automatically `true` in development
- No login required - automatically logged in as admin user
- Admin user is auto-created on first access

## Production Mode

### Authentication
- Authentication is **required** by default
- Set `DISABLE_AUTH=true` environment variable to disable auth (for testing/demos only)
- Users must register/login to access the application

### Required Environment Variables
```bash
# API Keys
GEMINI_API_KEY=your_gemini_api_key  # or LLM_API_KEY
TAVILY_API_KEY=your_tavily_api_key

# Email Configuration
MAILER_FROM="noreply@yourdomain.com"
MAILER_HOST="yourdomain.com"

# SMTP Configuration (required for sending emails)
SMTP_ADDRESS="smtp.gmail.com"
SMTP_PORT="587"
SMTP_USER_NAME="your-email@gmail.com"
SMTP_PASSWORD="your-app-password"
SMTP_DOMAIN="gmail.com"
SMTP_AUTHENTICATION="plain"
SMTP_ENABLE_STARTTLS="true"

# Database
POSTGRES_PASSWORD=your_password
RAILS_MAX_THREADS=5

# Optional: Disable authentication (production only)
DISABLE_AUTH=true
```

### Deployment
- **Platform:** Heroku
- **URL:** https://campaign-saas-7460a258bf90.herokuapp.com/
- **Database:** PostgreSQL (Heroku Essential-0 plan)
- **Node.js:** 16.x (pinned for Webpacker compatibility)
- **Ruby:** 3.3.9

Set environment variables via Heroku Config Vars:
```bash
heroku config:set GEMINI_API_KEY="your_key"
heroku config:set TAVILY_API_KEY="your_key"
heroku config:set SMTP_ADDRESS="smtp.gmail.com"
# ... etc
```

## Environment Variables

### Database
- `POSTGRES_PASSWORD` - PostgreSQL password
- `RAILS_MAX_THREADS` - Maximum threads (default: 5)

### API Keys
- `GEMINI_API_KEY` or `LLM_API_KEY` - Google Gemini API key for Writer/Design/Critique agents
- `TAVILY_API_KEY` - Tavily API key for Search agent

### Email Configuration
- `MAILER_FROM` - Sender email address (required)
- `MAILER_HOST` - Mail server domain for links (required)
- `SMTP_ADDRESS` - SMTP server address
- `SMTP_PORT` - SMTP server port (default: 587)
- `SMTP_USER_NAME` - SMTP username
- `SMTP_PASSWORD` - SMTP password (use app-specific password for Gmail)
- `SMTP_DOMAIN` - SMTP domain
- `SMTP_AUTHENTICATION` - Authentication method (default: plain)
- `SMTP_ENABLE_STARTTLS` - Enable STARTTLS (default: true)
- `MAIL_DELIVERY_METHOD` - Delivery method (file/test/smtp)

### Authentication
- `DISABLE_AUTH` - Disable authentication (development: auto-true, production: optional)

**Note:** The `.env` file is automatically loaded by `dotenv-rails` gem. Restart Rails server after modifying `.env`.

## Project Structure

```
saas-proj/
├── app/
│   ├── controllers/          # MVC controllers
│   │   ├── api/v1/          # RESTful API endpoints
│   │   └── campaigns_controller.rb
│   ├── models/              # ActiveRecord models
│   │   ├── user.rb          # User authentication
│   │   ├── campaign.rb      # Campaign management
│   │   ├── lead.rb          # Lead information
│   │   ├── agent_config.rb  # Agent configurations
│   │   └── agent_output.rb  # Agent execution results
│   ├── services/            # Business logic
│   │   ├── orchestrator.rb  # Agent pipeline coordinator
│   │   ├── agents/          # AI agents
│   │   │   ├── search_agent.rb
│   │   │   ├── writer_agent.rb
│   │   │   ├── design_agent.rb
│   │   │   └── critique_agent.rb
│   │   ├── lead_agent_service.rb    # Lead processing service
│   │   ├── email_sender_service.rb  # Email sending service
│   │   └── api_key_service.rb       # API key management
│   ├── javascript/          # React/TypeScript frontend
│   │   ├── components/      # React components
│   │   │   ├── campaigns/   # Campaign components
│   │   │   ├── leads/       # Lead components
│   │   │   ├── agents/      # Agent components
│   │   │   └── shared/      # Shared components
│   │   ├── hooks/           # Custom React hooks
│   │   ├── libs/            # API client and utilities
│   │   └── types/           # TypeScript definitions
│   └── views/               # ERB templates
├── db/                      # Database migrations and seeds
├── spec/                    # RSpec test suite (178 tests)
├── features/                # Cucumber tests
└── config/                  # Rails configuration
```

## AI Agent System

### Agent Pipeline
The system uses a multi-agent pipeline to process leads:

1. **SearchAgent** - Researches companies using Tavily API
   - Fetches recent news and information about target companies
   - Returns sources, company data, and research results

2. **WriterAgent** - Generates personalized emails using Gemini API
   - Creates B2B outreach emails based on research
   - Personalizes content for target company and recipient
   - Generates subject lines and email body

3. **DesignAgent** - Applies markdown formatting
   - Adds bold, italic, links, and other formatting
   - Enhances email readability and engagement
   - Outputs formatted email content

4. **CritiqueAgent** - Reviews email quality
   - Evaluates email effectiveness and personalization
   - Provides feedback and improvement suggestions
   - Scores email quality

### Orchestration
- **Orchestrator** - Coordinates the full pipeline (SEARCH → WRITER → DESIGN → CRITIQUE)
- **LeadAgentService** - Manages agent execution for individual leads
- **Stage Progression:** `queued → searched → written → critiqued → completed`

### Agent Configuration
- Each campaign has agent configurations (AgentConfig)
- Agents can be enabled/disabled per campaign
- Custom settings per agent (search depth, email length, critique strictness, etc.)

## Database Management

### Models
- **User** - User authentication and API key storage
- **Campaign** - Marketing campaigns with shared settings
- **Lead** - Lead information (name, email, company, title, stage, quality)
- **AgentConfig** - Agent configuration per campaign
- **AgentOutput** - Agent execution results and outputs

### Migrations
```bash
rails db:migrate        # Run migrations
rails db:rollback       # Rollback last migration
rails db:schema:load    # Load schema from db/schema.rb
```

### Seeds
```bash
rails db:seed
```

Creates:
- Admin user (`admin@example.com`)
- Sample campaign with default agent configs
- Sample leads
- Agent configurations (SEARCH, WRITER, CRITIQUE)

### Schema
- PostgreSQL with JSONB for settings and output data
- Foreign key constraints for data integrity
- Indexes on frequently queried fields

## UI Components

### Main Components
- **CampaignDashboard** - Main dashboard with campaigns and leads
- **CampaignForm** - Create/edit campaigns
- **CampaignSidebar** - Campaign list and navigation
- **ProgressTable** - Lead status and progress tracking
- **LeadForm** - Add/edit leads
- **AgentDashboard** - Agent execution and outputs
- **AgentOutputModal** - View agent outputs
- **AgentSettingsModal** - Configure agent settings
- **ApiKeyModal** - Manage API keys
- **Navigation** - Main navigation bar
- **EmptyState** - Empty state placeholder
- **Background** - Animated background component

### Technology
- **React 18** - UI framework
- **TypeScript** - Type safety
- **Tailwind CSS** - Styling
- **Webpacker** - Asset compilation

## Testing

The project includes comprehensive test coverage across three testing frameworks:

### RSpec
- **178 tests** with **90%+ line coverage**
- Tests cover models, controllers, services, and integration scenarios
- Run: `bundle exec rspec`
- Coverage report: `coverage/index.html`

### Jest
- **106 tests** with **96.6% coverage**
- Tests cover React components and hooks
- Run: `yarn test`
- Coverage: `yarn test:coverage`

### Cucumber
- **96 scenarios** with **497 steps** - **100% passing** ✅
- **19/19 API endpoints** covered (100%)
- User acceptance tests covering:
  - Authentication and authorization (401 responses for unauthenticated API requests)
  - Campaign CRUD operations (create, read, update, delete)
  - Lead management (create, update, delete, validation)
  - Agent workflows (run agents, retrieve outputs, update outputs, disabled agents)
  - Lead stage progression (queued → searched → written → critiqued → completed)
  - API key management (store and retrieve)
  - UI layout and assets (title, meta, icons, React mount)
  - Dashboard empty state
  - Input validation and authorization boundaries
  - Agent execution with error handling and disabled agent skipping

Run: `bundle exec cucumber`

**Code Coverage (SimpleCov):**
- **63.85% line coverage** (664/1040 lines)
- Run with coverage: `COVERAGE=true bundle exec cucumber`
- View report: `coverage/index.html`
- See `COVERAGE_REPORT.md` for detailed coverage analysis

**Coverage Analysis:**
- See `features/COVERAGE_ANALYSIS.md` for detailed coverage mapping and gap analysis
- See `features/HOW_TO_CHECK_COVERAGE.md` for methods to verify test coverage
- See `COVERAGE_REPORT.md` for SimpleCov coverage breakdown by file and category

## API Endpoints

### Campaigns
- `GET /api/v1/campaigns` - List campaigns
- `POST /api/v1/campaigns` - Create campaign
- `PUT /api/v1/campaigns/:id` - Update campaign
- `DELETE /api/v1/campaigns/:id` - Delete campaign
- `POST /api/v1/campaigns/:id/send_emails` - Send emails to ready leads

### Leads
- `GET /api/v1/leads` - List leads
- `POST /api/v1/leads` - Create lead
- `PUT /api/v1/leads/:id` - Update lead
- `DELETE /api/v1/leads/:id` - Delete lead
- `POST /api/v1/leads/:id/run_agents` - Execute AI agents
- `GET /api/v1/leads/:id/agent_outputs` - Retrieve agent outputs
- `PATCH /api/v1/leads/:id/update_agent_output` - Update agent output (WRITER, SEARCH, DESIGN)

### Agent Configs
- `GET /api/v1/campaigns/:campaign_id/agent_configs` - List agent configs
- `GET /api/v1/campaigns/:campaign_id/agent_configs/:id` - Get agent config
- `POST /api/v1/campaigns/:campaign_id/agent_configs` - Create agent config
- `PUT /api/v1/campaigns/:campaign_id/agent_configs/:id` - Update agent config
- `DELETE /api/v1/campaigns/:campaign_id/agent_configs/:id` - Delete agent config

### API Keys
- `GET /api/v1/api_keys` - Get API keys
- `PUT /api/v1/api_keys` - Update API keys

## Key Features

- **Campaign Management** - Create and manage marketing campaigns
- **Lead Processing** - Add and track leads with automated AI processing
- **AI Agent System** - Automated research, writing, design formatting, and critique
- **Email Generation** - Personalized B2B outreach emails
- **Email Sending** - Send formatted emails to leads with markdown support
- **User Authentication** - Secure user registration and login (Devise)
- **API Key Management** - Store and manage API keys per user
- **Real-time Progress Tracking** - Monitor lead processing status and quality metrics
- **Agent Configuration** - Customize agent settings per campaign
- **Responsive Design** - Mobile-first UI with Tailwind CSS

## Security

- CSRF protection enabled
- User authentication with Devise
- Rate limiting with Rack::Attack
- Content Security Policy (CSP)
- User-scoped data access
- SSL enforced in production
- API key encryption (stored in database)

## Available Scripts

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
bundle exec rspec            # Run RSpec tests (178 tests, 90%+ coverage)
yarn test                    # Run Jest tests (106 tests, 96.6% coverage)
yarn test:coverage           # Run Jest tests with coverage
bundle exec cucumber         # Run Cucumber tests (96 scenarios, 497 steps, 100% passing)
COVERAGE=true bundle exec cucumber  # Run Cucumber tests with code coverage (63.85% line coverage)
```

## Deployment

### Heroku
- **Database:** PostgreSQL (Heroku Essential-0 plan)
- **Redis:** Caching and rate limiting
- **Asset Pipeline:** Optimized CSS and JavaScript compilation
- **SSL/HTTPS:** Secure connections enforced
- **Environment Variables:** Secure API key management via Heroku Config Vars
- **Buildpacks:** Node.js and Ruby buildpacks configured
- **Asset Precompilation:** Optimized for production performance

### Production Checklist
- [ ] Set all required environment variables
- [ ] Configure SMTP for email sending
- [ ] Set `DISABLE_AUTH=false` or remove it (auth required by default)
- [ ] Configure `MAILER_HOST` with production domain
- [ ] Set up SSL/HTTPS
- [ ] Configure database backups
- [ ] Set up monitoring and error tracking

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License.

---

**Built with Rails, React, TypeScript, and Tailwind CSS**
