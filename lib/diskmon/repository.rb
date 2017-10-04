# module diskmon
module DiskMon
  require 'aws-sdk'

  # インスタンスのバリデーションを行うtrait
  module ValidateInstance
    def create_direct_access_instance(name)
      super(name).map { |i| validate_instance(i) }
    end

    def create_private_access_instance(name)
      super(name).map { |i| validate_instance(i) }
    end

    def create_proxied_instance(bastion_name, target_name)
      super(bastion_name, target_name).map { |i| validate_instance(i) }
    end

    private

    def validate_instance(instance)
      errors = instance.validate
      msg = "Instance(#{instance}) has some errors"
      raise InvalidStateError, msg, errors unless errors.empty?
      instance
    end
  end

  # EC2インスタンスのリポジトリ
  class InstanceRepository
    prepend ValidateInstance

    def initialize(cache_enabled = true)
      @ec2 = Aws::EC2::Client.new
      @cache = InstanceInfoCache.create(cache_enabled)
      @profile = Aws.config.key?(:profile) ? Aws.config[:profile] : 'default'
    end

    def find_instances_by_name(name)
      cache = @cache.fetch(@profile, name)
      return cache unless cache.nil?
      result = @ec2.describe_instances(filters: filter_option(name))
                   .reservations
                   .map(&:instances)
                   .flatten
      @cache.save(@profile, name, result)
      result
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

  # インスタンス情報のキャッシュ
  class InstanceInfoCache
    require 'pstore'

    def self.create(enabled)
      return NullCache.new unless enabled
      InstanceInfoCache.new
    end

    def initialize(file = '.ec2_cache', ttl = 60 * 60)
      @file = file
      @ttl = ttl
      @db = nil
    end

    def fetch(profile, name)
      db = open
      cache = nil
      db.transaction(read_only: true) do
        cache = db.fetch(key(profile, name), nil)
      end
      return nil if cache.nil?
      return nil if cache[:created_at] + @ttl < Time.now
      cache[:instances]
    end

    def save(profile, name, instances)
      db = open
      db.transaction do
        db[key(profile, name)] = {
          created_at: Time.now,
          instances: instances
        }
        db.commit
      end
    end

    private

    def open
      @db = PStore.new(@file) if @db.nil?
      @db
    end

    def key(profile, name)
      "#{profile}@@#{name}"
    end
  end

  # キャッシュしないキャッシュの実装
  class NullCache
    def initialize
      DiskMon.configuration.logger.warn('**WARN** cache disabled !!')
    end

    def fetch(_profile, _name)
      nil
    end

    def save(_profile, _name, _instances); end
  end
end
