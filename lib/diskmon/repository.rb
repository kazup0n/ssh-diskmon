# module diskmon
module DiskMon
  require 'aws-sdk'
  # EC2インスタンスのリポジトリ
  class InstanceRepository
    def initialize
      @ec2 = Aws::EC2::Client.new
    end

    def find_instances_by_name(name)
      result = @ec2.describe_instances(filters: filter_option(name))
      result.reservations.map(&:instances).flatten
    end

    def create_direct_access_instance(name)
      find_instances_by_name(name).map do |instance|
        DirectAccessInstance.new(
          instance.instance_id,
          instance.key_name,
          instance.public_dns_name,
          name
        )
      end
    end

    def create_bastion_instance(name)
      find_instances_by_name(name).map do |instance|
        BastionInstance.new(instance.instance_id,
                            instance.key_name,
                            instance.public_dns_name,
                            name)
      end.first
    end

    def create_private_access_instance(name)
      find_instances_by_name(name).map do |instance|
        PrivateAccessInstance.new(
          instance.instance_id,
          instance.key_name,
          instance.private_dns_name,
          name
        )
      end
    end

    def create_proxied_instance(bastion_name, target_name)
      bastion = create_bastion_instance(bastion_name)
      create_private_access_instance(target_name).map do |instance|
        ProxiedInstance.new(bastion, instance)
      end
    end

    private

    def filter_option(name)
      [{
        name: 'tag:Name', values: [name]
      }]
    end
  end
end
