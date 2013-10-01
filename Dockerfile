# Ubuntu base image
FROM ubuntu

# Add this directory to /
ADD . /hoosegow

WORKDIR /hoosegow

RUN script/bootstrap-ruby
RUN bundle
RUN bundle exec rspec

ENTRYPOINT ["hoosegow"]
