require 'optparse'

class Option

    attr_reader :opts

    def initialize(opts)
        @opts = opts
    end

    def self.configure
        option = Option.new(self.parse)
        option.configure_aws
        option.opts
    end

    def configure_aws
        Aws.config[:profile] = opts[:profile] unless opts[:profile].nil?
        Aws.config[:region] = opts[:region] unless opts[:region].nil?
    end

    private

    def self.parse(argv = ARGV)
        parser = OptionParser.new
        opts = {
            profile: nil,
            show_ssh: false,
            format: :compact,
            region: nil
        }
        parser.on('--profile VALUE', "profile(default: #{opts[:profile]})") {|v| opts[:profile] = v}
        parser.on('--show-ssh', "show ssh console login command (default: #{opts[:show_ssh]})") {|v| opts[:show_ssh] = v}
        parser.on('--format VALUE', "output format (compact, json, table, default: #{opts[:format]})") {|v| opts[:format] = v.to_sym}
        parser.on('--region VALUE', "region (default: #{opts[:region]})") {|v| opts[:region] = v}

        begin
            args = parser.parse(argv)
        rescue OptionParser::InvalidOption => e
            usage(parser, e.message)
        end
        opts
    end

    private
    def self.usage(parser, msg)
        puts parser.to_s
        puts "error: #{msg}" if msg
        exit 1
    end


end
