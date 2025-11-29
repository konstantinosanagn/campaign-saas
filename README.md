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
- **Node.js:** **20.0.0 or higher (latest LTS 24.x recommended)** ⚠️ **REQUIRED**
  - This project uses Shakapacker (Webpack 5) which requires Node.js 20+
  - The installation will fail if you don't have the correct Node.js version
  - Check your version: `node --version`
  - Download latest LTS: https://nodejs.org/
  - Or use nvm: `nvm install 24 && nvm use 24`
- **Yarn:** 1.22.x

## Installation

### Quick Start (Recommended)

```bash
# 1. Clone and enter the repository
git clone <your-repo-url>
cd campaign-saas

# 2. ⚠️ IMPORTANT: Install Node.js 20+ (latest LTS 24.x recommended)
#    The installation will automatically check and fail if Node.js version is too old.
#    
#    Option A: Download from https://nodejs.org/ (recommended for most users)
#    Option B: Using nvm (Node Version Manager)
#      nvm install 24
#      nvm use 24
#      # Or if .nvmrc exists: nvm use
#
#    Verify installation: node --version (should show v20.x.x or higher)

# 3. Run automated setup (installs Ruby gems, sets up database)
bin/setup --skip-server

# 4. Install JavaScript dependencies
#    This will automatically check Node.js version and fail if < 20.0.0
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
   - **Node.js 20.0.0+ (latest LTS 24.x recommended)** ⚠️ **REQUIRED**
     - Check version: `node --version`
     - Download: https://nodejs.org/
     - Or use nvm: `nvm install 24 && nvm use 24`
     - The `yarn install` command will automatically verify Node.js version
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

### Gmail OAuth Test Mode

⚠️ Currently in Google OAuth Test Mode. Only `campaignsaastester@gmail.com` is authorized for Gmail OAuth.

## Project Structure

```
campaign-saas/
├── app/
│   ├── controllers/     # MVC controllers
│   ├── models/           # ActiveRecord models
│   ├── services/         # Business logic & AI agents
│   ├── javascript/       # React/TypeScript frontend
│   └── views/            # ERB templates
├── db/                   # Database migrations and seeds
├── spec/                  # RSpec test suite
├── features/              # Cucumber tests
└── config/                # Rails configuration
```

## AI Agent System

Multi-agent pipeline: **SearchAgent** → **WriterAgent** → **CritiqueAgent** → **DesignAgent**

- **SearchAgent** - Researches companies using Tavily API
- **WriterAgent** - Generates personalized emails using Gemini API
- **CritiqueAgent** - Reviews email quality and selects best variant
- **DesignAgent** - Applies markdown formatting

Stage progression: `queued → searched → written → critiqued → designed → completed`

## Testing

```bash
bundle exec rspec      # RSpec tests
yarn test              # Jest tests
bundle exec cucumber   # Cucumber tests
```

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
bundle exec rspec            # Run RSpec tests
yarn test                    # Run Jest tests
yarn test:coverage           # Run Jest tests with coverage
bundle exec cucumber         # Run Cucumber tests
```

## Deployment





## Deployment

**Platform:** Heroku  
**URL:** https://campaign-saas-7460a258bf90.herokuapp.com/

Set environment variables via Heroku Config Vars:
```bash
heroku config:set GEMINI_API_KEY="your_key"
heroku config:set TAVILY_API_KEY="your_key"
```

## Docker

```bash
docker build -t campaign_manager .
docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value> --name campaign_manager campaign_manager
```

## Troubleshooting

### Node.js Version Issues

If you see an error like "Node.js version 20.0.0 or higher is required" during `yarn install`:

1. **Check your current Node.js version:**
   ```bash
   node --version
   ```

2. **If version is too old (< 20.0.0), install the latest LTS:**
   ```bash
   # Option A: Download from https://nodejs.org/
   # Option B: Using nvm (if installed)
   nvm install 24
   nvm use 24
   # Or simply: nvm use (if .nvmrc exists)
   ```

3. **Verify the installation:**
   ```bash
   node --version  # Should show v20.x.x or higher
   ```

4. **Clear yarn cache and retry:**
   ```bash
   yarn cache clean
   yarn install
   ```

**Note:** The `preinstall` script in `package.json` automatically checks Node.js version before installing dependencies. This ensures compatibility with Shakapacker (Webpack 5) which requires Node.js 20+.

### Database Connection Issues

If you see PostgreSQL connection errors:
- Ensure PostgreSQL is running: `pg_isready` or check your PostgreSQL service
- Verify database credentials in `config/database.yml`
- Check that the database exists: `rails db:create`

### Port Already in Use

If port 3000 is already in use:
```bash
rails server -p 3001
```

