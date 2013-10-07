# Hoosegow

A Docker jail for native rendering code.

## Install on Ubuntu 12.04

#### 1. Install Docker

```bash
sudo apt-get update
sudo apt-get install linux-image-generic-lts-raring linux-headers-generic-lts-raring curl
sudo reboot
```

**Go get a beer while Ubuntu reboots.**

```bash
sudo sh -c "curl https://get.docker.io/gpg | apt-key add -"
sudo sh -c "echo deb http://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list"
sudo apt-get update
sudo apt-get install lxc-docker
```

#### 2. Build hoosegow image

The Docker image is built when Hoosegow is initialized, but the first run can take a long time. You can get this run out of the way by running a rake task.

```bash
rake bootstrap_docker
```

**Go get another beer while ruby builds.**

#### 3. Run tests

```bash
rake spec
```

## Usage

Hoowgow runs both in your code and in a Docker container. When you call `render_*` on a Hoosegow instance, it proxies the method call to another instance of Hoosegow running inside a docker container.

#### Connecting to Docker

By default Docker's API listens locally on a Unix socket. If you are running Docker with it's default configuration, you don't need to worry about configuring Hoosegow.

**Configure Hoosegow to connect to a non-standard Unix socket.**

```ruby
h = Hoosegow.new :socket => '/path/to/socket'
h.render_reverse 'foobar'
# => "raboof"
```

**Configure Hoosegow to connect to a Docker daemon running on another computer.**

```ruby
h = Hoosegow.new :host => '192.168.1.192', :port => 4243
h.render_reverse 'foobar'
# => "raboof"
```

#### Rendering a file

To render a file, you call the `Hoosegow#render_#{type}` for any render function defined. This method call will be proxied to another Hoosegow instance running in a docker container.

```ruby
input    = "hello world!"
output   = hoosegow.render_reverse input
# => "!dlrow olleh"
```

## Extending

Adding the ability to render a new file type is easy. Just add a new `render_#{type}` method to the `Hoosegow::Render` module in `lib/hoosegow/render/#{type}.rb`.

```ruby
# File: lib/hoosegow/render/join.rb

class Hoosegow
  module Render
    def render_join(*args)
      args.join "_"
    end
  end
end
```
