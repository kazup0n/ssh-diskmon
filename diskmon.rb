require 'sshkit'
require 'aws-sdk'
require 'yaml'
require './lib/diskmon'

SSHKit.config.output_verbosity = Logger::ERROR
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
    cap  = instance.run_command('df -h')
    m = cap.match(/^\/dev\/xvda1\s+(?<size>[0-9.]+)G\s+(?<used>[0-9.]+)G\s+(?<avail>[0-9.]+)G\s+(?<use_percent>[0-9]+)%/)
    h = {
        name: instance.to_s,
        size: m[:size].to_i,
        used: m[:used].to_i,
        avail: m[:avail].to_i,
        use_percent: m[:use_percent].to_i,
    }
end.sort_by{|r| r[:use_percent] }.reverse.each do |r|
    puts [r[:use_percent].to_s + '%', r[:used].to_s + 'G', r[:avail].to_s + 'G'].join(",") + "@" + r[:name]
end

# direct access
# DiskMon::InstanceRepository.new.create_direct_access_instance('mbapp-prd-ec2-bastion').each{|instance| instance.run_command('ls -F')}