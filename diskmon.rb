require 'sshkit'
require 'aws-sdk'
require 'yaml'
require './lib/diskmon'

SSHKit.config.output_verbosity = Logger::DEBUG
Aws.config[:profile] = 'sbj-prd'


class MonitorTargetInstanceBuilder

        def initialize(repos)
            @repos = repos
        end

        def create_instances_from_file(filename: 'hosts.yml')
            config = YAML.load(File.read(filename))
            hosts = config['hosts']
            hosts.map do |bastion, names|
                names.map{|name| @repos.create_proxied_instance(bastion, name) }
            end.flatten
        end

end


MonitorTargetInstanceBuilder.new(DiskMon::InstanceRepository.new).create_instances_from_file.map do |instance|
    puts instance
    puts instance.ssh_command
    instance.run_command('df -h')
    puts ""
end

# direct access
# DiskMon::InstanceRepository.new.create_direct_access_instance('mbapp-prd-ec2-bastion').each{|instance| instance.run_command('ls -F')}