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

```bash
sudo script/bootstrap-docker
```

**Go get another beer while ruby builds.**

#### 3. Run tests

```bash
rspec
```

## Usage

Hoosegow has two main components, the `Guard` and the `Convict`. The `Convict` is intended to run inside of a docker container and does the actual work of rendering files. The `Guard` launches and manages docker instances. As a simple demonstration, `Convict` has the `render_reverse` ability, which reverses the input string.

#### Configuring Hoosegow

You can tell Hoosegow if Docker is running in a non-standard location or if we are using a non-standard docker image.

```ruby
Hoosegow.docker_host  = 'localhost'
Hoosegow.docker_port  = 4243
Hoosegow.docker_image = 'hoosegow'
```

#### Rendering a file

To render a file, you call the `Hoosegow::Guard#render_#{type}` function for a type defined in `Hoosegow::Convict`. Call the `Guard` function with whatever arguments the `Convict` function accepts.

```ruby
input  = "hello world!"
output = Hoosegow::Guard.render_reverse input
# => "!dlrow olleh"
```

## Extending

Adding the ability to render a new file type is easy. Just add a new `render_#{type}` method to `Hoosegow::Convict`. For the sake of organization, add these files to `lib/hoosegow/convict/#{type}.rb`

```ruby
# File: lib/hoosegow/convict/join.rb

class Hoosegow
  class Convict
    class << self
      def render_join(*args, separator = '_')
        args.join separator
      end
    end
  end
end
```
