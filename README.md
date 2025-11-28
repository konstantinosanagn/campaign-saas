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
- **Node.js:** 18+ (latest LTS recommended)
- **Yarn:** 1.22.x

## Installation

### Quick Start (Recommended)

```bash
# 1. Clone and enter the repository
git clone <your-repo-url>
cd campaign-saas

# 2. Install Node.js 20+ from https://nodejs.org/ (if needed)

# 3. Run automated setup (installs Ruby gems, sets up database)
bin/setup --skip-server

# 4. Install JavaScript dependencies
yarn install

# 5. Start the application (requires two terminals)
# Terminal 1: Webpack frontend (hot reload)
chmod +x ./bin/webpack-dev-server
./bin/webpack-dev-server

# Terminal 2: Rails backend
rails server
```

Open **http://localhost:3000** - automatically logged in as `admin@example.com`

**Note:** The `.env` file is optional for development - defaults are provided. Create it with `cp .env.example .env` if you want to customize settings.

### Manual Setup (Alternative)

If you prefer manual setup:

1. **Install prerequisites:**
   - Ruby 3.3.9+
   - Node.js 18+ (latest LTS recommended)
   - PostgreSQL 12+
   - Yarn 1.22.x

2. **Install dependencies:**
   ```bash
   bundle install
   yarn install
   ```

3. **Setup database:**
   ```bash
   rails db:setup  # Creates, migrates, and seeds in one command
   ```

4. **Start the application:**
   ```bash
   # Terminal 1: Rails server
   rails server
   
   # Terminal 2: Webpack dev server (for hot reload)
   ./bin/webpack-dev-server
   ```

## Development Mode

### Default User
- **Email:** `admin@example.com`
- **Password:** `password123`
- Auto-login enabled (no authentication required)

### Default API Keys
API keys are automatically populated for the admin user:
- **LLM_API_KEY:** `AIzaSyAmvrDiciuHNW_Pjy9_h5jUGw_2R2k6-xI`
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
A .env file including the following environment variable is required:
```bash
GMAIL_CLIENT_ID=104902845705-j48s5c8e64ccoic198g5gqmb8lfvf4re.apps.googleusercontent.com
GMAIL_CLIENT_SECRET=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

# Optional: Disable authentication (production only)
DISABLE_AUTH=true
```

### Gmail OAuth Test Mode (Work in Progress -- not part of iteration 2)

⚠️ The app is currently in **Google OAuth Test Mode** ("In testing"), which means Google restricts OAuth access to protect user data. Only accounts listed as Test users in the Google Cloud Console are allowed to authorize the app, and all other Google accounts will be blocked with a 403 error.

Because the Gmail OAuth scope (`gmail.send`) is considered sensitive, the unverified app can only be used with approved test accounts. 

**For this iteration, only `campaignsaastester@gmail.com` is authorized**, so Gmail OAuth will only work when this address is entered as the "Send From Email Address" in Email Settings.

![Gmail OAuth Test Mode](docs/gmail-oauth-test-mode.png)

***Disclaimer: While we aimed to have the sender ready for iteration 2 and have the skelton set up, its functionality depends on authorization set up for various user accounts -- which we are targetting by the demo day (stay tuned!). In this iteration our focus remained on the other agents by enhancing their functionality (ex: impriving search agent parameters to collect more relevent sources, generating variants of the writer agent outputs and critiquing them all to ensure highest quality outputs as well as refining our prompt engineering strategy to focus on key metrics such as tone and business synergy/ personalization as our target users are small B2B companies/ startups.)

**To use Gmail OAuth:** (Work in Progress -- not part of iteration 2)
1. Navigate to Email Settings in the application
2. Enter `campaignsaastester@gmail.com` as the "Send From Email Address"
3. Complete the OAuth flow with this authorized test account

### Deployment
- **Platform:** Heroku
- **URL:** https://campaign-saas-7460a258bf90.herokuapp.com/
- **Database:** PostgreSQL (Heroku Essential-0 plan)
- **Node.js:** 18+ (latest LTS recommended)
- **Ruby:** 3.3.9

Set environment variables via Heroku Config Vars:
```bash
heroku config:set GEMINI_API_KEY="your_key"
heroku config:set TAVILY_API_KEY="your_key"
# ... etc
```

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
├── spec/                    # RSpec test suite (584 examples)
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

3. **CritiqueAgent** - Reviews email quality
   - Evaluates email effectiveness and personalization
   - Provides feedback and improvement suggestions
   - Scores email quality
   - Selects best variant from multiple revisions

4. **DesignAgent** - Applies markdown formatting
   - Adds bold, italic, links, and other formatting
   - Enhances email readability and engagement
   - Outputs formatted email content
   - Configurable formatting options (format, allow_bold, allow_italic, allow_bullets, cta_style, font_family)

### Orchestration
- **Orchestrator** - Coordinates the full pipeline (SEARCH → WRITER → CRITIQUE → DESIGN)
- **LeadAgentService** - Manages agent execution for individual leads
- **Stage Progression:** `queued → searched → written → critiqued → designed → completed`

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
- **Shakapacker (Webpack 5)** - Asset compilation

## Testing

The project includes comprehensive test coverage across three testing frameworks:

### RSpec
- **776 examples, 0 failures** ✅
- **100.0% line coverage** (1424/1424 lines)
- Tests cover models, controllers, services, and integration scenarios
- Comprehensive coverage of all AI agents (Search, Writer, Critique, Design)
- Full pipeline progression testing (queued → searched → written → critiqued → designed)
- Run: `bundle exec rspec`
- Coverage report: `coverage/index.html`

### Cucumber
- **247 scenarios** with **1862 steps** - **100% passing** ✅
- **85.25% line coverage** (1214/1424 lines)
- User acceptance tests covering:
  - Authentication and authorization
  - Campaign CRUD operations (create, read, update, delete)
  - Lead management (create, update, delete, validation)
  - Agent workflows (run agents, retrieve outputs, update outputs, disabled agents)
  - Lead stage progression (queued → searched → written → critiqued → designed → completed)
  - DESIGN agent execution and stage progression (newly added)
  - Orchestrator standalone service testing (newly added)
  - AgentOutput model status methods (completed?, failed?, pending?)
  - Controller error handling and edge cases
  - API key management (store and retrieve)
  - UI layout and assets (title, meta, icons, React mount)
  - Dashboard empty state
  - Input validation and authorization boundaries
  - Agent execution with error handling and disabled agent skipping
  - Email sending functionality
- Run: `bundle exec cucumber`
- Run with coverage (SimpleCov): `COVERAGE=true bundle exec cucumber`
- View report: `coverage/index.html`


### Jest
- **210 tests passed, 20 test suites** ✅
- Tests cover React components, hooks, and utilities
- Comprehensive component testing including CampaignDashboard, AgentDashboard, AgentOutputModal, and more
- Custom hooks testing (useCampaigns, useLeads, useApiKeys, useSelection, useTypewriter)
- Run: `yarn test`
- Coverage: `yarn test:coverage`


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
bundle exec rspec            # Run RSpec tests (584 examples, 0 failures, 81.64% coverage)
yarn test                    # Run Jest tests (210 tests passed, 20 test suites)
yarn test:coverage           # Run Jest tests with coverage
bundle exec cucumber         # Run Cucumber tests (120 scenarios, 654 steps, 100% passing)
COVERAGE=true bundle exec cucumber  # Run Cucumber tests with code coverage (76.14% line coverage)
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

## Troubleshooting

### Database Connection Issues

If you see PostgreSQL connection errors:
- Ensure PostgreSQL is running: `pg_isready` or check your PostgreSQL service
- Verify database credentials in `config/database.yml`
- Check that the database exists: `rails db:create`

### Port Already in Use

If port 3000 is already in use:
```bash
# Use a different port
rails server -p 3001
```

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
