require 'optparse'

# CLIオプション
class Option
  DEFAULTS = {
    profile: nil,
    show_ssh: false,
    format: :compact,
    region: nil,
    hosts: 'default'
  }.freeze

  attr_reader :opts

  def initialize(opts)
    @opts = opts
  end

  def self.configure
    option = Option.new(Parser.new(DEFAULTS).parse)
    option.configure_aws
    option.opts
  end

  def configure_aws
    Aws.config[:profile] = opts[:profile] unless opts[:profile].nil?
    Aws.config[:region] = opts[:region] unless opts[:region].nil?
  end

  # CLI Parser
  class Parser < OptionParser
    def initialize(opts)
      super
      @opts = opts.dup
      setup
    end

    def parse(args = ARGV)
      super(args)
      @opts
    rescue OptionParser::InvalidOption => e
      usage(e.msg)
      exit 1
    end

    private

    def assign(name, desc, key)
      on(name, desc + " (default #{@opts[key]})") do |v|
        @opts[key] = v
      end
    end

    def usage(msg)
      puts to_s
      puts "error: #{msg}" if msg
    end

    def setup
      assign('--profile VALUE', 'profile', :profile)
      assign('--show-ssh', 'show ssh console login command', :show_ssh)
      on('--format VALUE', 'output format (compact, json, table)') do |v|
        @opts[:format] = v.to_sym
      end
      assign('--region VALUE', 'region', :region)
      assign('--hosts VALUE', 'hosts', :hosts)
    end
  end
end
