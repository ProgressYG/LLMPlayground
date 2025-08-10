# Ruby 3.3.0 base image
FROM ruby:3.3.0-slim

# Install dependencies
RUN apt-get update -qq && apt-get install -y \
    build-essential \
    libpq-dev \
    nodejs \
    npm \
    curl \
    git \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /rails

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3

# Copy package.json and install node packages
COPY package.json package-lock.json ./
RUN npm ci --only=production

# Copy the rest of the application
COPY . .

# Precompile assets
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

# Create necessary directories
RUN mkdir -p tmp/pids tmp/sockets log storage

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/up || exit 1

# Start the Rails server
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]