# Stage 1: Build Stage
FROM ruby:3.1 AS builder

# Set the working directory
WORKDIR /usr/src/app

# Install Node.js (v16.x) and other dependencies
RUN apt-get update -qq && \
    apt-get install -y curl python3 gnupg build-essential libpq-dev && \
    curl -sL https://deb.nodesource.com/setup_16.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g yarn

# Install the correct version of Bundler
RUN gem install bundler:2.1.4

# Copy Gemfile and Gemfile.lock to install Ruby dependencies
COPY Gemfile Gemfile.lock ./

# Install gems into a specific path
RUN bundle install --jobs 4 --retry 5 --path /usr/local/bundle

# Install Node.js dependencies for asset building
COPY package.json yarn.lock ./
RUN yarn install

# Copy the rest of the application code (including the app folder)
COPY . .

# Precompile assets
RUN bundle exec rake assets:precompile RAILS_ENV=production

# Stage 2: Runtime Stage
FROM ruby:3.1-slim AS runtime

# Set the working directory for the final image
WORKDIR /app

# Install minimal dependencies and Node.js for the runtime
RUN apt-get update -qq && \
    apt-get install -y libpq-dev && \
    curl -sL https://deb.nodesource.com/setup_16.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Copy the application code from the build stage
COPY --from=builder /usr/src/app /app

# Copy the gems from the builder stage
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Set environment variables
ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_APP_CONFIG=/usr/local/bundle \
    PATH=/usr/local/bundle/bin:$PATH

# Expose the port the app runs on
EXPOSE 3000

# Set the command to run the application
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
