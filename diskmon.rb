require 'sshkit'
require 'aws-sdk'
require 'yaml'
require './lib/diskmon'
require 'optparse'
require 'date'

SSHKit.config.output_verbosity = Logger::ERROR

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



# parse opts
opts, args = Option.new.parse

# configure aws
Aws.config[:profile] = opts[:profile] unless opts[:profile].nil?
Aws.config[:region] = opts[:region] unless opts[:region].nil?

formatter = BasicFormat.create(opts)

timestamp = Time.now.to_datetime.rfc3339.freeze


result = MonitorTargetInstanceBuilder.new(DiskMon::InstanceRepository.new).create_instances_from_file.map do |instance|
    cap  = instance.run_command('df -h')
    m = cap.match(/^\/dev\/xvda1\s+(?<size>[0-9.]+)G\s+(?<used>[0-9.]+)G\s+(?<avail>[0-9.]+)G\s+(?<use_percent>[0-9]+)%/)
    h = {
        timestamp: timestamp,
        name: instance.to_s,
        size: m[:size].to_i,
        used: m[:used].to_i,
        avail: m[:avail].to_i,
        use_percent: m[:use_percent].to_i,
        ssh: instance.ssh_command
    }
end.sort_by{|r| r[:use_percent] }.reverse

formatter.format(result)