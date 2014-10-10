# Ubuntu base image
FROM ubuntu

# Install rbenv deps
RUN apt-get update
RUN apt-get install -y build-essential zlib1g-dev libssl-dev openssl libreadline-dev sqlite3 libsqlite3-dev libxslt-dev libxml2-dev curl wget git-core

# Install rbenv
RUN git clone https://github.com/sstephenson/rbenv.git /.rbenv
RUN echo 'export PATH="/.rbenv/bin:$PATH"' >> /etc/profile
RUN echo 'export RBENV_ROOT="/.rbenv"'     >> /etc/profile
RUN echo 'eval "$(rbenv init -)"'          >> /etc/profile

# Install rbenv build plugin
RUN mkdir -p /.rbenv/plugins
RUN git clone https://github.com/sstephenson/ruby-build.git /.rbenv/plugins/ruby-build

# Install 2.1.3
RUN /bin/bash -l -c 'rbenv install 2.1.3'
RUN /bin/bash -l -c 'rbenv global 2.1.3'
RUN /bin/bash -l -c 'gem install bundler'
RUN /bin/bash -l -c 'rbenv rehash'

# Create a user to run as.
RUN adduser --no-create-home --disabled-password --gecos "" --shell /bin/false hoosegow

###########################################################################################
# Anything added after the ADD command will not be cached. Try to add changes above here. #
###########################################################################################

# Add this directory to /
ADD . /hoosegow
RUN chown -R hoosegow:hoosegow /hoosegow

# Switch to limited user now.
USER hoosegow

# Run all commands in /hoosegow
WORKDIR /hoosegow

# Bundle hoosegow
RUN /bin/bash -l -c 'BUNDLE_JOBS=4 bundle install --path .bundle --without development test'

# Command to run when `docker run hoosegow`
ENTRYPOINT /bin/bash -l -c bin/hoosegow
