# Hoosegow

Ephemeral Docker jails for running untrusted Ruby code.

Hoosegow runs both in your code and in a Docker container. When you call a method on a Hoosegow instance, it proxies the method call to another instance of Hoosegow running inside a Docker container.

# Security

Hoosegow is intended to add a layer of security to projects that need to run code that is not fully trusted/audited. Because the untrusted code is running inside a Docker container, an attacker who manages to exploit a vulnerability in the code must also break out of the Docker container before gaining any access to the host system.

This means that Hoosegow is only as strong as Docker. Docker employs Kernel namespaces, capabilities, and cgroups to contain processes running inside a container. This is not true virtualization though, and a process running as root inside the container *can* compromise the host system. Any privilege escalation bugs in the host Kernel could also be used to become root and compromise the host machine. Further hardening of the base Ubuntu image, along with tools like AppArmor or SE-Linux can improve the security posture of an application relying on Hoosegow/Docker.

The following are some useful resources regarding the security of Docker:

- The [Docker Security](https://docs.docker.com/articles/security/) article from Docker.io.
- The [LXC, Docker, Security](http://www.slideshare.net/jpetazzo/linux-containers-lxc-docker-and-security) slides from Jérôme Petazzoni.
- The series of Docker security articles from Daniel J. Walsh ([one](http://opensource.com/business/14/7/docker-security-selinux), [two](http://opensource.com/business/14/9/security-for-docker)). 

#### Installing

Gems are available from the [releases page](https://github.com/github/hoosegow/releases). Download a gem to
your app's `vendor/cache` directory, and add this to your Gemfile:

    gem "hoosegow"

#### Defining Methods to Proxy

You need to define the methods you want to have run in the Docker container. To do this, you need to create a `inmate.rb` file that defines a `Hoosegow::Inmate` module. Any methods on this module will be available on `Hoosegow` instances and will be proxied to the Docker container. Here is an example `inmate.rb` file:

```ruby
class Hoosegow
  module Inmate
    def reverse(input)
      input.reverse
    end
  end
end
```

The `inmate.rb` file should be in its own folder, with an optional `Gemfile` to specify dependencies. This directory will be copied to the Docker container at build time so your methods are available to be proxied to. You specify the location of the directory containing the `inmate.rb` file when instantiating a `Hoosegow` object:

```ruby
hoosegow = Hoosegow.new :inmate_dir => File.join(RAILS_ROOT, "hoosegow_deps")
hoosegow.reverse "foobar"
#=> "raboof"
```

#### Building the Docker Image

Before you can start using Hoosegow, you need to build the Docker image that Hoosegow will proxy method calls to. This can be done in a rake task or bootstrap script:

```ruby
hoosegow = Hoosegow.new :inmate_dir => File.join(RAILS_ROOT, "hoosegow_deps")
hoosegow.build_image
hoosegow.image_name
#=> "hoosegow:2f8f155e72828ddab9bd8bd0e355c47fb01a5323"
```

The image will need to be rebuilt with any changes to Hoosegow or the `inmate.rb` file. If the image is built ahead of time (by a rake task or bootstrap script), you can pass the name of the image to use when instantiating a Hoosegow instance:

```ruby
ENV['HOOSEGOW_IMAGE']
#=> "hoosegow:2f8f155e72828ddab9bd8bd0e355c47fb01a5323"
hoosegow = Hoosegow.new :inmate_dir => File.join(RAILS_ROOT, "hoosegow_deps")
                        :image_name => ENV['HOOSEGOW_IMAGE']
```

#### Configuring the Connection to Docker

By default Docker's API listens locally on a Unix socket. If you are running Docker with it's default configuration, you don't need to worry about configuring Hoosegow.

**Configure Hoosegow to connect to a non-standard Unix socket.**

```ruby
Hoosegow.new :socket => '/path/to/socket'
```

**Configure Hoosegow to connect to a Docker daemon running on another computer.**

```ruby
Hoosegow.new :host => '192.168.1.192', :port => 4243
```
