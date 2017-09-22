class BasicFormat

    attr_reader :opts

    def initialize(opts)
        @opts = opts
    end

    def self.create(opts)
        case opts[:format]
        when :json
            JsonFormat.new(opts)
        when :compact
            CompactFormat.new(opts)
        when :table
            TableFormat.new(opts)
        else
            raise ArgumentError.new("Invalid format: #{opts[:format]}")
        end
            
    end

end


class CompactFormat < BasicFormat

    def format(result)
        result.each do |r|
            puts [r[:use_percent].to_s + '%', r[:used].to_s + 'G', r[:avail].to_s + 'G'].join(",") + "@" + r[:name]
            puts r[:ssh] if opts[:show_ssh]
        end
    end

end

class JsonFormat < BasicFormat

    def format(result)
        result.each do |r|
            copy = r.dup
            copy.delete :ssh unless opts[:show_ssh]
            puts copy.to_json
        end
    end

end

class TableFormat < BasicFormat

    require 'table_print'

    def format(result)
        unless opts[:show_ssh]
            tp result, except: :ssh
        else
            tp result
        end
    end

end