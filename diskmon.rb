require 'aws-sdk'
require 'sshkit'
require 'sshkit/dsl'
require 'yaml'

SSHKit.config.output_verbosity = Logger::DEBUG


class TargetInstance < Struct.new(:instance_id, :key, :host, :name)
end

class BastionInstance < TargetInstance

    include SSHKit::DSL

    def run_command(remote_host, key, command)
        ssh_host = SSHKit::Host.new(remote_host)
        ssh_host.user = "ec2-user"
        ssh_host.ssh_options = {
            proxy: to_proxy,
            auth_methods: %w(publickey),
            keys: [to_real_key(key)]
        }
        on ssh_host do
            execute command
        end
    end

    def to_proxy
        proxy = Net::SSH::Proxy::Command.new("ssh ec2-user@#{host} -o stricthostkeychecking=no -W %h:%p -i #{to_real_key(key)}")
    end

    def to_real_key(key)
        File.join(ENV['HOME'], '.ssh', "#{key}.pem")
    end

    def to_remote_key(key)
        File.join('/home/ec2-user/.ssh/', key + '.pem')
    end

end


class InstanceRepository

    def initialize
        @ec2 = Aws::EC2::Client.new
    end

    def find_internal_host_by_name(name)
        result = @ec2.describe_instances(filters: filter_option(name))
        result.reservations.map do | reservation |
            reservation.instances.map do |instance|
                TargetInstance.new(instance.instance_id, instance.key_name, instance.private_dns_name, name)
            end
        end.flatten
    end

    def find_bastion_by_name(name)
        result = @ec2.describe_instances(filters: filter_option(name))
        instance = result.reservations.first.instances.first
        BastionInstance.new(instance.instance_id, instance.key_name, instance.public_dns_name, name)
    end

    def filter_option(name)
        [{
            name: 'tag:Name', values: [name]
        }]
    end

end

class Hostfile

    def initialize(repos)
        @repos = repos
    end

    def load(filename: 'hosts.yml')
        repos = @repos
        config = YAML.load(File.read(filename))
        hosts = config['hosts']
        hosts.map do |bastion_name, names|
            bastion = repos.find_bastion_by_name(bastion_name)
            targets = names.map {|name| repos.find_internal_host_by_name(name)}.flatten
            {bastion: bastion, targets: targets}
        end
    end

end

Aws.config[:profile] = 'sbj-prd'

hosts = Hostfile.new(InstanceRepository.new).load

hosts.each do |h|
    h[:targets].each do |t| 
        puts t.name + "@" + t.instance_id
        h[:bastion].run_command(t.host, t.key, 'df -H') 
    end
end