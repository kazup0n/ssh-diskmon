require 'sshkit'
require 'sshkit/dsl'

module DiskMon
  DEFAULT_USER = 'ec2-user'.freeze

  # インスタンスのバリデーション時のエラー
  class InstanceValidationException < StandardError
    attr_reader :errors

    def initialize(msg, errors)
      super(msg)
      @errors = errors
    end
  end

  # インスタンス変数のValidate
  module ValidateNil
    def self.included(base)
      base.class_eval do
        def self.validatable(*syms)
          @validatables ||= []
          syms.each do |sym|
            sym = '@' + sym.to_s unless sym.to_s.start_with?('@')
            @validatables << sym
          end
          validatables = @validatables = @validatables.uniq
          define_method :validate do
            validatables.map do |sym|
              "#{sym}  is nil" if instance_variable_get(sym).nil?
            end.compact
          end
        end
      end
    end
  end

  # Support for private keys
  module KeySupport
    def to_real_key(key)
      File.join(ENV['HOME'], '.ssh', "#{key}.pem")
    end
  end

  # インスタンスの骨格実装
  class BasicInstance
    include KeySupport
    include ValidateNil

    validatable :instance_id, :key, :host, :name
    attr_reader :instance_id, :key, :host, :name

    def initialize(instance_id, key, host, name)
      @instance_id = instance_id
      @key = key
      @host = host
      @name = name
    end

    def validate
      %i[@instance_id @key @host @name].map do |sym|
        "#{sym}  is nil" if instance_variable_get(sym).nil?
      end.compact
    end

    def create_ssh_host
      ssh_host = SSHKit::Host.new(host)
      ssh_host.user = DEFAULT_USER
      ssh_host.ssh_options = ssh_options
      ssh_host
    end

    def ssh_options
      {
        auth_methods: %w[publickey],
        keys: [to_real_key(key)]
      }
    end

    def to_s
      "#{name}(id=#{instance_id}, host=#{host})"
    end
  end

  # 直接アクセス可能なインスタンス
  class DirectAccessInstance < BasicInstance
    include SSHKit::DSL

    def run_command(command)
      cap = nil
      on create_ssh_host do
        cap = capture(command)
      end
      cap
    end

    def ssh_command
      "ssh -i #{to_real_key(key)} #{DEFAULT_USER}@#{host}"
    end
  end

  # VPC内からのみアクセス可能なインスタンス
  class PrivateAccessInstance < BasicInstance; end

  # 踏み台インスタンス
  class BastionInstance < DirectAccessInstance
    def ssh_options
      options = super
      options[:proxy] = Net::SSH::Proxy::Command.new(proxy_command)
      options
    end

    def proxy_command
      %W[
        ssh ec2-user@#{host}
        -o StrictHostKeyChecking=no
        -W %h:%p
        -i #{to_real_key(key)}
      ].join(' ')
    end
  end

  # 踏み台経由でアクセス可能なインスタンス
  class ProxiedInstance
    include KeySupport
    include ValidateNil
    include SSHKit::DSL

    attr_reader :bastion, :target
    validatable :bastion, :target

    def initialize(bastion, target)
      @bastion = bastion
      @target = target
    end

    def run_command(command)
      ssh_host = @target.create_ssh_host
      ssh_host.ssh_options = @bastion.ssh_options
      cap = nil
      on(ssh_host) { cap = capture(command) }
      cap
    end

    def ssh_command
      remote_host = @target.host
      remote_key = @target.key
      proxy_command = @bastion.proxy_command
      %W[
        ssh -oProxyCommand='#{proxy_command}'
        #{DEFAULT_USER}@#{remote_host}
        -i #{to_real_key(remote_key)}
      ].join(' ')
    end

    def to_s
      "#{@target.name}(#{@target.instance_id}) via #{@bastion.name}"
    end
  end
end
