# Testing Production Mode Locally

This guide explains how to test your application in production mode locally to simulate deployment behavior.

## Quick Start

```bash
# 1. Compile assets for production
npm run build

# 2. Set up production database (uses development DB by default for safety)
RAILS_ENV=production rails db:create db:migrate db:seed

# 3. Precompile assets (Rails will use the npm build output)
RAILS_ENV=production rails assets:precompile

# 4. Start Rails in production mode (with SSL disabled for local testing)
RAILS_ENV=production DISABLE_SSL=true rails server
```

## Detailed Steps

### Step 1: Compile Frontend Assets

Production mode requires precompiled assets. Build your React/TypeScript frontend:

```bash
npm run build
```

This runs `webpack --config config/webpack/production.js` and creates optimized, minified bundles.

### Step 2: Set Up Production Database

**Option A: Use Development Database (Recommended for Testing)**
```bash
# Temporarily point production to development database
RAILS_ENV=production rails db:create db:migrate
```

**Option B: Create Separate Production Database**
```bash
# Create a separate production database
RAILS_ENV=production rails db:create
RAILS_ENV=production rails db:migrate
RAILS_ENV=production rails db:seed
```

### Step 3: Precompile Rails Assets

Rails needs to know about the compiled assets:

```bash
RAILS_ENV=production rails assets:precompile
```

This will:
- Use the compiled webpack bundles from `npm run build`
- Generate asset manifests
- Optimize asset delivery

### Step 4: Disable SSL for Local Testing

Production mode enforces SSL by default. To test locally without SSL, temporarily disable it:

**Option A: Environment Variable (Recommended)**
```bash
# Windows PowerShell
$env:DISABLE_SSL="true"; $env:RAILS_ENV="production"; rails server

# Windows CMD
set DISABLE_SSL=true && set RAILS_ENV=production && rails server

# Linux/Mac
DISABLE_SSL=true RAILS_ENV=production rails server
```

**Option B: Modify config/environments/production.rb temporarily**
```ruby
# Temporarily comment out these lines:
# config.assume_ssl = true
# config.force_ssl = true
```

### Step 5: Start the Server

```bash
# Windows PowerShell
$env:RAILS_ENV="production"; rails server

# Windows CMD
set RAILS_ENV=production && rails server

# Linux/Mac
RAILS_ENV=production rails server
```

The app will be available at **http://localhost:3000**

## Key Differences in Production Mode

1. **No Hot Reload**: Changes require recompiling assets and restarting the server
2. **Optimized Assets**: Minified JavaScript, CSS, and optimized images
3. **Eager Loading**: All code is loaded at startup (faster runtime, slower startup)
4. **Caching Enabled**: Action Controller caching is enabled
5. **Error Handling**: Full error pages instead of detailed stack traces
6. **Background Jobs**: Uses production job queue (ActiveJob with Solid Queue)

## Testing Background Jobs

Production mode uses background jobs for agent execution. Make sure the job processor is running:

```bash
# In a separate terminal
RAILS_ENV=production rails jobs:work
```

Or use the Solid Queue dashboard (if configured):
```bash
RAILS_ENV=production rails solid_queue:start
```

## Environment Variables

Production mode may require additional environment variables. Check your `.env` file or set them:

```bash
# Windows PowerShell
$env:DATABASE_URL="postgresql://localhost/campaign_manager_production"
$env:RAILS_ENV="production"

# Linux/Mac
export DATABASE_URL="postgresql://localhost/campaign_manager_production"
export RAILS_ENV="production"
```

## Troubleshooting

### Assets Not Loading

1. **Clear compiled assets and rebuild:**
   ```bash
   rm -rf public/packs public/assets tmp/cache
   npm run build
   RAILS_ENV=production rails assets:precompile
   ```

2. **Check asset paths:**
   - Verify `public/packs` contains compiled assets
   - Check `public/packs/manifest.json` exists

### Database Connection Issues

1. **Use development database temporarily:**
   ```bash
   # Point production to development DB
   RAILS_ENV=production rails db:drop db:create db:migrate
   ```

2. **Or create separate production database:**
   ```bash
   # Update config/database.yml production section if needed
   RAILS_ENV=production rails db:create
   ```

### SSL Errors

If you see SSL redirect errors:

1. **Use DISABLE_SSL environment variable:**
   ```bash
   DISABLE_SSL=true RAILS_ENV=production rails server
   ```

2. **Or temporarily disable in config/environments/production.rb:**
   ```ruby
   # Comment out:
   # config.assume_ssl = true
   # config.force_ssl = true
   ```

### Background Jobs Not Running

1. **Start the job processor:**
   ```bash
   RAILS_ENV=production rails jobs:work
   ```

2. **Check job queue:**
   ```bash
   RAILS_ENV=production rails console
   # Then in console:
   SolidQueue::Job.count
   ```

## Returning to Development Mode

After testing, return to development mode:

```bash
# Just run normally (development is default)
rails server

# In another terminal
./bin/webpack-dev-server
```

## Quick Test Script

Create a script `test-production.sh` (or `test-production.ps1` for Windows):

**Linux/Mac (`test-production.sh`):**
```bash
#!/bin/bash
set -e

echo "Building frontend assets..."
npm run build

echo "Precompiling Rails assets..."
RAILS_ENV=production rails assets:precompile

echo "Starting production server (SSL disabled)..."
DISABLE_SSL=true RAILS_ENV=production rails server
```

**Windows PowerShell (`test-production.ps1`):**
```powershell
Write-Host "Building frontend assets..."
npm run build

Write-Host "Precompiling Rails assets..."
$env:RAILS_ENV="production"
rails assets:precompile

Write-Host "Starting production server (SSL disabled)..."
$env:DISABLE_SSL="true"
$env:RAILS_ENV="production"
rails server
```

Make executable and run:
```bash
chmod +x test-production.sh
./test-production.sh
```

## Notes

- **Performance**: Production mode is slower to start but faster to run
- **Debugging**: Use `rails console` in production mode for debugging
- **Logs**: Check `log/production.log` for detailed logs
- **Database**: Consider using a separate production database to avoid affecting development data
