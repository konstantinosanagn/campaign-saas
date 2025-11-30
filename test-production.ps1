# Test Production Mode Locally
# This script builds assets and starts Rails in production mode

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Testing Production Mode Locally" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Build frontend assets
Write-Host "Step 1: Building frontend assets..." -ForegroundColor Yellow
npm run build
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to build frontend assets" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Frontend assets built successfully" -ForegroundColor Green
Write-Host ""

# Step 2: Precompile Rails assets
Write-Host "Step 2: Precompiling Rails assets..." -ForegroundColor Yellow
$env:RAILS_ENV = "production"
rails assets:precompile
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to precompile Rails assets" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Rails assets precompiled successfully" -ForegroundColor Green
Write-Host ""

# Step 3: Check if database exists
Write-Host "Step 3: Checking production database..." -ForegroundColor Yellow
rails db:version RAILS_ENV=production 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Database doesn't exist. Creating and migrating..." -ForegroundColor Yellow
    rails db:create RAILS_ENV=production
    rails db:migrate RAILS_ENV=production
    rails db:seed RAILS_ENV=production
    Write-Host "✓ Database created and seeded" -ForegroundColor Green
} else {
    Write-Host "✓ Database exists" -ForegroundColor Green
}
Write-Host ""

# Step 4: Start production server
Write-Host "Step 4: Starting production server..." -ForegroundColor Yellow
Write-Host "Server will be available at: http://localhost:3000" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host ""

# Disable SSL for local testing
$env:DISABLE_SSL = "true"
$env:RAILS_ENV = "production"

# Start the server
rails server
