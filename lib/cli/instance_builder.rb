require 'yaml'

# EC2インスタンスを検索、生成するビルダー
class InstanceBuilder
  def initialize(repos = DiskMon::InstanceRepository.new)
    @repos = repos
  end

  def create_instances_from_file(filename: 'hosts.yml')
    config = YAML.safe_load(File.read(filename))
    hosts = config['hosts']
    hosts.map do |bastion, names|
      names.map { |name| @repos.create_proxied_instance(bastion, name) }
    end.flatten
  end
end
