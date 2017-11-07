# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/xenial64"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "512"
  end

  (0..5).each do |n|
		do_autostart = n <= 2
    config.vm.define "node-#{n}", autostart: do_autostart do |c|
        c.vm.hostname = "node-#{n}"
        c.vm.network "private_network", ip: "192.168.222.1#{n}"
        c.vm.provision :shell, :path => "scripts/vagrant/setup-routes.bash"

        c.vm.provision :shell, :path => "scripts/install-tools"
        c.vm.provision :shell, :path => "scripts/install-hab"
        if n == 0
          c.vm.provision :shell, :path => "scripts/install-hab-sup-service"
        else
          c.vm.provision :shell, :path => "scripts/install-hab-sup-service", :args => "--peer 192.168.222.1#{n-1}"
        end
    end
  end
end
