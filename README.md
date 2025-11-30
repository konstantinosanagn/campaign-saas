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
- **npm:** 10.7.0+ (comes with Node.js)

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
npm install

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
     - The `npm install` command will automatically verify Node.js version
   - PostgreSQL 12+
   - npm 10.7.0+ (comes with Node.js)

2. **Install dependencies:**
   ```bash
   bundle install
   npm install
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

### API Keys
**Important:** API keys are no longer automatically assigned in development. You must manually add them:

1. Start the application and log in as `admin@example.com`
2. Click on your user profile (top right)
3. Navigate to the API Keys section
4. Add your API keys:
   - **Gemini API Key** (for Writer, Critique, and Design agents)
   - **Tavily API Key** (for Search agent)

Get your API keys:
- **Gemini API Key:** https://aistudio.google.com/app/apikey
- **Tavily API Key:** https://tavily.com/

### Email Sending Setup

The application uses **Gmail OAuth** for sending emails. There are two ways to set this up:

#### Option 1: Use Your Own Gmail Account (Recommended for Development)

1. **Set up Google OAuth Client:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Navigate to **APIs & Services** → **Credentials**
   - Create a new **OAuth 2.0 Client ID** (or use existing)
   - Application type: **Web application**
   - Add authorized redirect URI:
     ```
     http://localhost:3000/users/auth/google_oauth2/callback
     ```
   - Copy the **Client ID** and **Client Secret**

2. **Configure in `.env`:**
   ```bash
   cp .env.example .env
   ```
   
   Add to your `.env` file:
   ```env
   GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
   GOOGLE_CLIENT_SECRET=your-client-secret
   ```

3. **Connect Gmail in the App:**
   - Log in to the application
   - Click on your user profile (top right)
   - Click **"Connect Gmail"** button
   - Authorize the application to send emails on your behalf
   - Your Gmail account will now be used for sending campaign emails

#### Option 2: Use Default System Sender (For Testing)

If you don't want to connect your own Gmail, you can use a default system sender:

1. **Set up a system Gmail account:**
   - Create a Gmail account (e.g., `campaignsenderagent@gmail.com`)
   - Set up Google OAuth for this account (same steps as Option 1)
   - Connect this account via Google OAuth in the app

2. **Configure in `.env`:**
   ```env
   DEFAULT_GMAIL_SENDER=campaignsenderagent@gmail.com
   ```

3. **The system will:**
   - Automatically use this account when users haven't connected their own Gmail
   - Display "Using default sender" in the UI
   - Hide the "Connect Gmail" button when default sender is available

**Note:** The default sender must be a user in the database with Gmail OAuth connected. You can create this user via Google OAuth login or manually in the database.

#### Email Sending Priority

The application tries email sending methods in this order:

1. **User's Gmail OAuth** (if user connected their Gmail via Google login)
2. **Default Gmail Sender** (if `DEFAULT_GMAIL_SENDER` is configured and that user has Gmail connected)
3. **SMTP Fallback** (if neither Gmail option is available)

### Authentication
- `DISABLE_AUTH` is automatically `true` in development
- No login required - automatically logged in as admin user
- Admin user is auto-created on first access
- **For Google OAuth testing:** Set `DISABLE_AUTH=false` in `.env` to test the full OAuth flow

## Production Mode

### Authentication
- Authentication is **required** by default
- Set `DISABLE_AUTH=true` environment variable to disable auth (for testing/demos only)
- Users must register/login to access the application

### Required Environment Variables

For production, set these environment variables in Heroku:

```bash
# Google OAuth (required for Gmail sending)
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret

# Optional: Default Gmail sender (system account)
DEFAULT_GMAIL_SENDER=campaignsenderagent@gmail.com

# API Keys (user-specific, but can set defaults)
GEMINI_API_KEY=your-gemini-key
TAVILY_API_KEY=your-tavily-key

# Optional: Disable authentication (testing only)
DISABLE_AUTH=false
```

### Google OAuth Setup for Production

1. **Create OAuth 2.0 Client in Google Cloud Console:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Navigate to **APIs & Services** → **Credentials**
   - Create **OAuth 2.0 Client ID** (Web application)
   - Add authorized redirect URI:
     ```
     https://your-app-name.herokuapp.com/users/auth/google_oauth2/callback
     ```
   - Enable **Gmail API** in the APIs & Services section

2. **Set environment variables in Heroku:**
   ```bash
   heroku config:set GOOGLE_CLIENT_ID="your-client-id" -a campaign-saas
   heroku config:set GOOGLE_CLIENT_SECRET="your-client-secret" -a campaign-saas
   heroku config:set DEFAULT_GMAIL_SENDER="system-email@gmail.com" -a campaign-saas
   ```

3. **Run database migrations:**
   ```bash
   heroku run rails db:migrate -a campaign-saas
   ```

### Email Sending in Production

- Users can connect their Gmail via **"Continue with Google"** login
- If a user hasn't connected Gmail, the system uses the `DEFAULT_GMAIL_SENDER` (if configured)
- All emails are sent via **Gmail API** (not SMTP) for better deliverability
- Gmail tokens are automatically refreshed when they expire

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
npm test               # Jest tests
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
npm test                     # Run Jest tests
npm run test:coverage        # Run Jest tests with coverage
bundle exec cucumber         # Run Cucumber tests
```

## Deployment

**Platform:** Heroku  
**URL:** https://campaign-saas-7460a258bf90.herokuapp.com/

### Required Environment Variables

Set environment variables via Heroku Config Vars:

```bash
# Google OAuth (required for Gmail sending)
heroku config:set GOOGLE_CLIENT_ID="your-client-id" -a campaign-saas
heroku config:set GOOGLE_CLIENT_SECRET="your-client-secret" -a campaign-saas

# Optional: Default Gmail sender
heroku config:set DEFAULT_GMAIL_SENDER="system-email@gmail.com" -a campaign-saas

# API Keys (optional - users can add their own)
heroku config:set GEMINI_API_KEY="your_key" -a campaign-saas
heroku config:set TAVILY_API_KEY="your_key" -a campaign-saas
```

### Database Migrations

After deploying new migrations, run:

```bash
heroku run rails db:migrate -a campaign-saas
```

### Post-Deployment Checklist

1. ✅ Run database migrations
2. ✅ Set Google OAuth credentials
3. ✅ Configure default Gmail sender (optional)
4. ✅ Test Google OAuth login
5. ✅ Verify Gmail sending works

## Docker

```bash
docker build -t campaign_manager .
docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value> --name campaign_manager campaign_manager
```

## Troubleshooting

### Node.js Version Issues

If you see an error like "Node.js version 20.0.0 or higher is required" during `npm install`:

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

4. **Clear npm cache and retry:**
   ```bash
   npm cache clean --force
   npm install
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

