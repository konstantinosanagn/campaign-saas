#!/usr/bin/env node

/**
 * Check Node.js version before installation
 * Ensures Node.js 20.0.0 or higher is installed (required for Shakapacker/Webpack 5)
 */

const MIN_NODE_VERSION = '20.0.0';

function parseVersion(version) {
  // Remove 'v' prefix if present
  const cleanVersion = version.replace(/^v/, '');
  const parts = cleanVersion.split('.').map(Number);
  return {
    major: parts[0] || 0,
    minor: parts[1] || 0,
    patch: parts[2] || 0
  };
}

function compareVersions(current, minimum) {
  const currentVersion = parseVersion(current);
  const minimumVersion = parseVersion(minimum);

  if (currentVersion.major > minimumVersion.major) return true;
  if (currentVersion.major < minimumVersion.major) return false;

  if (currentVersion.minor > minimumVersion.minor) return true;
  if (currentVersion.minor < minimumVersion.minor) return false;

  return currentVersion.patch >= minimumVersion.patch;
}

const currentNodeVersion = process.version;
const isValidVersion = compareVersions(currentNodeVersion, MIN_NODE_VERSION);

if (!isValidVersion) {
  console.error('\n❌ Node.js version check failed!\n');
  console.error(`   Current version: ${currentNodeVersion}`);
  console.error(`   Required version: >= ${MIN_NODE_VERSION}\n`);
  console.error('   This project requires Node.js 20.0.0 or higher.');
  console.error('   Please install the latest LTS version from: https://nodejs.org/\n');
  console.error('   Or using nvm:');
  console.error('     nvm install 24');
  console.error('     nvm use 24\n');
  process.exit(1);
}

console.log(`✓ Node.js version check passed: ${currentNodeVersion} (>= ${MIN_NODE_VERSION})`);
