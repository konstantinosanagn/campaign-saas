# Quick Start Guide - CampAIgn

Get up and running with CampAIgn in 3 steps!

## 1. Install Dependencies

```bash
# Install Ruby dependencies
bundle install
```

## 2. Configure API Keys

Create a `.env` file in the project root:

```bash
cp .env.example .env
```

Then edit `.env` and add your API keys:

```bash
TAVILY_API_KEY=your_tavily_api_key_here
OPENAI_API_KEY=your_openai_api_key_here
```

**Where to get API keys:**
- **Tavily**: Sign up at https://tavily.com
- **OpenAI**: Get your API key from https://platform.openai.com

## 3. Run the Application

### Basic Usage

Generate a personalized B2B email:

```bash
ruby main.rb 'artificial intelligence'
```

### With Recipient and Company

Generate a personalized email for a specific person:

```bash
ruby main.rb 'AI automation' 'John Doe' 'TechCorp'
```

### Examples

```bash
# General B2B marketing email
ruby main.rb 'machine learning'

# Personalized for a specific CMO
ruby main.rb 'data analytics' 'Sarah Chen' 'DataViz Inc'

# Outreach for VP of Engineering
ruby main.rb 'cloud computing' 'Michael Park' 'CloudTech Solutions'
```

## What Happens

1. **SearchAgent** - Searches for latest news and information about your domain
2. **WriterAgent** - Generates a personalized B2B marketing email
3. **CritiqueAgent** - Reviews the email for quality and effectiveness

## Running Tests

```bash
# Run all tests
bundle exec rspec

# Run with detailed output
bundle exec rspec --format documentation

# Or use rake
rake spec
```

## Troubleshooting

### Error: "Could not find gem"
```bash
bundle install
```

### Error: "TAVILY_API_KEY not found"
Make sure your `.env` file exists and has valid API keys.

### Error: "OpenAI error: Invalid API Key"
Double-check your OpenAI API key in the `.env` file.

## Project Structure

```
campAIgn/
├── main.rb              # Entry point
├── orchestrator.rb      # Coordinates agents
├── search_agent.rb      # Searches for info
├── writer_agent.rb      # Generates emails
├── critique_agent.rb    # Reviews emails
├── spec/                # Tests
└── .env                 # Your API keys (create this!)
```

## Next Steps

- Read [README.md](README.md) for more details
- Check [TESTING.md](TESTING.md) for testing documentation
- See `spec/writer_agent_spec.rb` for test examples



