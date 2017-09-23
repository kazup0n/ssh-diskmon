require './lib/diskmon'
require 'table_print'

# parse opts
opts = Option.configure

instances = InstanceBuilder.new.create_instances_from_file.map do |instance|
  {
    name: instance.target.name,
    ssh: instance.ssh_command
  }
end

if opts[:format] == :table
  tp(instances, { name: { width: 50 } }, ssh: { width: 300 })
else
  puts instances.to_json
end
