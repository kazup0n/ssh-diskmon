
# DiskMon module
module DiskMon
  # 設定
  class Configuration
    require 'logger'

    attr_reader :logger

    def initialize(opts)
      @logger = use_verbosity(opts[:verbose])
      @logger.debug(opts)
      configure_aws(opts)
    end

    def configure_aws(opts)
      Aws.config[:profile] = opts[:profile] unless opts[:profile].nil?
      Aws.config[:region] = opts[:region] unless opts[:region].nil?

      @logger.debug("Aws.config[:profile] = #{Aws.config[:profile]}")
      @logger.debug("Aws.config[:region] = #{Aws.config[:region]}")
    end

    private

    def use_verbosity(verbosity)
      SSHKit.config.output_verbosity = verbosity
      logger = Logger.new(STDOUT)
      logger.level = Logger.const_get(verbosity.to_s.upcase)
      logger
    end
  end

  class << self
    def configuration(opts = nil)
      return @configuration if opts.nil?
      @configuration ||= Configuration.new(opts)
    end
  end
end
