# CampAIgn - AI-Powered Campaign Management Platform

A modern SaaS application for managing AI-powered marketing campaigns with intelligent agent workflows. Built with Ruby on Rails and React, featuring automated lead processing through AI agents.

## 🎯 Project Overview

CampAIgn is a comprehensive campaign management platform that automates the entire lead processing pipeline using AI agents. Users can create campaigns, add leads, and let the AI system automatically research companies, generate personalized emails, and provide quality feedback.

## 🏗️ How It Works

### AI Agent Pipeline
1. **Search Agent** - Researches target companies using Tavily API for real-time news and information
2. **Writer Agent** - Generates personalized B2B outreach emails using Google Gemini API
3. **Critique Agent** - Reviews email quality and provides improvement suggestions
4. **Orchestrator** - Coordinates the entire pipeline and manages agent execution

### User Workflow
1. **Create Campaign** - Set up campaign with base prompts and agent configurations
2. **Add Leads** - Import or manually add lead information (name, email, company, title)
3. **Run Agents** - Execute AI agents to process leads automatically
4. **Review Outputs** - View and edit agent-generated content through the UI
5. **Track Progress** - Monitor lead processing status and quality metrics

## 📁 Codebase Structure

```
web/                          # Root directory (Rails application)
├── app/
│   ├── controllers/           # MVC controllers
│   │   ├── api/v1/           # RESTful API endpoints
│   │   └── concerns/         # Shared controller logic
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
│   │   ├── critique_agent.rb # Quality review agent
│   │   └── lead_agent_service.rb # Lead processing service
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

## 🚀 Quick Start

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

Create a `.env` file in the root `web/` directory:

```bash
# Database
POSTGRES_PASSWORD=your_password
RAILS_MAX_THREADS=5

# API Keys (for AI agents)
GEMINI_API_KEY=your_gemini_api_key
TAVILY_API_KEY=your_tavily_api_key

# Optional: Disable authentication in development (default: true)
# In development mode, you're automatically logged in as admin@example.com
DISABLE_AUTH=true
```

## 🛠️ Development Mode

In development mode, the application automatically:
- **Disables authentication** - No need to register or login
- **Creates admin user** - Automatically logs you in as `admin@example.com`
- **Uses default password** - `password123` (if you need to login manually)
- **Auto-creates user** - The admin user is created automatically on first access

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
- **AI Agent System** - Automated research, writing, and critique
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

- **178 RSpec tests** - 100% line coverage
- **106 Jest tests** - 96.6% coverage
- Integration tests for complete workflows
- Component tests for UI elements
- API endpoint testing

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
- `GET/POST/PUT/DELETE /api/v1/leads` - Lead management
- `GET/POST/PUT/DELETE /api/v1/campaigns/:id/agent_configs` - Agent configuration
- `POST /api/v1/leads/:id/run_agents` - Execute AI agents
- `GET /api/v1/leads/:id/agent_outputs` - Retrieve agent outputs

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License.

---

## 📋 TODO List

### Phase 6: Advanced Features
- [ ] **Real-time Features** - ActionCable channels for live updates
- [ ] **File Uploads** - Active Storage for document attachments
- [ ] **Background Jobs** - Sidekiq for async processing
- [ ] **Redis Caching** - Performance optimization
- [ ] **API Documentation** - Swagger/OpenAPI specs

### Phase 7: Deployment & Monitoring
- [x] **Heroku Deployment** - Production deployment completed
- [ ] **Docker Compose** - Local development environment
- [ ] **CI/CD Pipeline** - GitHub Actions automation
- [ ] **Error Tracking** - Sentry integration
- [ ] **Performance Monitoring** - APM tools
- [x] **Backup Strategy** - Heroku PostgreSQL automatic backups

### Deployment Process Completed
- [x] **Database Configuration** - Updated to use DATABASE_URL for Heroku
- [x] **Asset Pipeline** - Fixed Webpacker and Tailwind CSS compilation
- [x] **Node.js Compatibility** - Pinned to version 16.x for Webpacker
- [x] **Asset Preloading** - Resolved preloading conflicts
- [x] **Database Migrations** - Successfully ran on Heroku
- [x] **Environment Variables** - Configured for production

### Code Quality & Maintenance
- [ ] **RuboCop** - Ruby code quality checks
- [ ] **ESLint** - JavaScript/TypeScript linting
- [ ] **Pre-commit Hooks** - Automated quality checks
- [ ] **API Rate Limiting** - Enhanced throttling
- [ ] **Security Headers** - Additional security measures

---

**Built with ❤️ using Rails, React, TypeScript, and Tailwind CSS**