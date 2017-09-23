require 'sshkit'
require './lib/diskmon'
require 'date'

SSHKit.config.output_verbosity = Logger::ERROR

# parse opts
opts = Option.configure

formatter = BasicFormat.create(opts)

timestamp = Time.now.to_datetime.rfc3339.freeze

instances = InstanceBuilder.new.create_instances_from_file.map do |instance|
  cap = instance.run_command('df -h')
  m = cap.match(%r{^/dev/xvda1\s+
  (?<size>[0-9.]+)G\s+
  (?<used>[0-9.]+)G\s+
  (?<avail>[0-9.]+)G\s+
  (?<use_percent>[0-9]+)%}x)

  {
    timestamp: timestamp,
    name: instance.to_s,
    size: m[:size].to_i,
    used: m[:used].to_i,
    avail: m[:avail].to_i,
    use_percent: m[:use_percent].to_i,
    ssh: instance.ssh_command
  }
end
instances.sort_by { |r| r[:use_percent] }.reverse

formatter.format(result)
