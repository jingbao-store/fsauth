FROM ruby:3.3-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    libyaml-dev \
    libssl-dev \
    zlib1g-dev \
    nodejs \
    npm \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Gemfile
COPY Gemfile Gemfile.lock ./

# Install Ruby dependencies
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3

# Copy package.json
COPY package.json package-lock.json ./

# Install Node dependencies
RUN npm ci --production

# Copy application code
COPY . .

# Set dummy SECRET_KEY_BASE for asset precompilation
ENV SECRET_KEY_BASE_DUMMY=1 \
    RAILS_ENV=production \
    NODE_ENV=production

# Compile assets
RUN npm run build:css && \
    bundle exec rails assets:precompile

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s \
  CMD curl -f http://localhost:3000/ || exit 1

# Start script
CMD ["sh", "-c", "bundle exec rails db:migrate && bundle exec puma -C config/puma.rb"]
