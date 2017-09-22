class Option

    def parse(argv = ARGV)
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
        [opts, args]
    end

    private
    def usage(parser, msg)
        puts op.to_s
        puts "error: #{msg}" if msg
        exit 1
    end

end
