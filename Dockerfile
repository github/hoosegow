# Ubuntu base image
FROM ubuntu

# Install rbenv deps
RUN apt-get update
RUN apt-get install -y build-essential zlib1g-dev libssl-dev openssl libreadline-dev sqlite3 libsqlite3-dev libxslt-dev libxml2-dev curl wget git-core

# Install rbenv
RUN git clone https://github.com/sstephenson/rbenv.git /.rbenv
RUN echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> /.profile
RUN echo 'eval "$(rbenv init -)"' 				>> /.profile

# Install rbenv build plugin
RUN mkdir -p /.rbenv/plugins
RUN git clone https://github.com/sstephenson/ruby-build.git /.rbenv/plugins/ruby-build

# Install 1.9.3
RUN /bin/bash -l -c 'rbenv install 1.9.3-p448'
RUN /bin/bash -l -c 'rbenv global 1.9.3-p448'
RUN /bin/bash -l -c 'gem install bundler'
RUN /bin/bash -l -c 'rbenv rehash'

# Run all commands in /hoosegow
RUN mkdir /hoosegow
WORKDIR /hoosegow

###########################################################################################
# Anything added after the ADD command will not be cached. Try to add changes above here. #
###########################################################################################

# Add this directory to /
ADD . /hoosegow

# Bundle hoosegow
RUN /bin/bash -l -c 'bundle install'

# Command to run when `docker run hoosegow`
ENTRYPOINT ["/bin/bash", "-l", "-c", "bin/hoosegow"]
