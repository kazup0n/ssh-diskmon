require 'sshkit'
require 'sshkit/dsl'

module DiskMon

    DEFAULT_USER = 'ec2-user'


    module KeySupport

        def to_real_key(key)
            File.join(ENV['HOME'], '.ssh', "#{key}.pem")
        end
    end

    class BasicInstance

        include KeySupport

        attr_reader :instance_id, :key, :host, :name

        def initialize(instance_id, key, host, name)
            @instance_id = instance_id
            @key = key
            @host = host
            @name = name
        end

        def create_ssh_host
            ssh_host = SSHKit::Host.new(host)
            ssh_host.user = DEFAULT_USER
            ssh_host.ssh_options = ssh_options
            ssh_host
        end


        def ssh_options
            {
                auth_methods: %w(publickey),
                keys: [to_real_key(key)]
            }
        end


        def to_s
            "#{name}(id=#{instance_id}, host=#{host})"
        end

    end

    class DirectAccessInstance < BasicInstance

        include SSHKit::DSL

        def run_command(command)
            on create_ssh_host do
                execute command
            end
        end

        def ssh_command
            "ssh -i #{to_real_key(key)} #{DEFAULT_USER}@#{host}"
        end

    end

    class PrivateAccessInstance < BasicInstance; end

    class BastionInstance < DirectAccessInstance

        def ssh_options
            options = super
            options[:proxy] = Net::SSH::Proxy::Command.new("ssh ec2-user@#{host} -o stricthostkeychecking=no -W %h:%p -i #{to_real_key(key)}")
            options
        end

    end
    
    class ProxiedInstance

        include KeySupport
        include SSHKit::DSL

        def initialize(bastion, target)
            @bastion = bastion
            @target = target
        end

        def run_command(command)
            ssh_host = @target.create_ssh_host
            ssh_host.ssh_options = @bastion.ssh_options
            on(ssh_host) { execute command }
        end
    
        def ssh_command
            host = @bastion.host
            key = @bastion.key
            remote_host = @target.host
            remote_key = @target.key
            "ssh -oProxyCommand='ssh -W %h:%p ec2-user@#{host} -i #{to_real_key(key)}' #{DEFAULT_USER}@#{remote_host} -i #{to_real_key(remote_key)}"
        end

        def to_s
            "#{@target.to_s} via #{@bastion.to_s}"
        end
    
    end
end