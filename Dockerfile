# Ubuntu base image
FROM ubuntu

# Add this directory to /
ADD . /hoosegow

# Run all commands in /hoosegow
WORKDIR /hoosegow

# Install rbenv and versions
RUN script/bootstrap-ruby

RUN bundle install
RUN bundle exec rspec

# Command to run when `docker run hoosegow`
ENTRYPOINT ["hoosegow"]
