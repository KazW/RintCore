require 'rint_core/g_code/codes'

module RintCore
  module GCode
    # Represents a single line in a GCode file, parse expression tester: {http://rubular.com/}
    class Line
      include RintCore::GCode::Codes

      # @!macro attr_accessor
      #   @!attribute [rw] $1
      #     @param speed_multiplier [Numeric] number speed (F) will be multiplied by.
      #     @return [nil] if the speed multiplier is not set.
      #     @return [Numeric] the speed multiplier (print moves only).
      #   @!attribute [rw] $2
      #     @param extrusion_multiplier [Numeric] number extrusions (E) will be multiplied by.
      #     @return [nil] if the extrusion multiplier is not set.
      #     @return [Numeric] the extrusion multiplier.
      #   @!attribute [rw] $3
      #     @param travel_multiplier [Numeric] number travel move speeds (F) will be multiplied by.
      #     @return [nil] if the travel multiplier is not set.
      #     @return [Numeric] the travel multiplier.
      #   @!attribute [rw] $4
      #     @param tool_number [Fixnum] the tool used in the command.
      #     @return [Fixnum] the tool used in the command.
      #   @!attribute [rw] $5
      #     @param f [Float] speed of the command (in mm/minute).
      #     @return [Float] the speed of the command (in mm/minute).
      attr_accessor :speed_multiplier, :extrusion_multiplier,
                    :travel_multiplier, :tool_number, :f

      # @!macro attr_reader
      #   @!attribute [r] $1
      #     @return [String] the line, upcased and stripped of whitespace.
      #   @!attribute [r] $2
      #     @return [nil] if the line wasn't valid GCode.
      #     @return [MatchData] the raw matches from the regular expression evaluation.
      attr_reader :raw, :matches

      # GCode matching pattern
      GCODE_PATTERN = /^(?<line>(?<command>((?<command_letter>[G|M|T])(?<command_number>\d{1,3}))) ?(?<regular_data>([S](?<s_data>\d*))? ?([P](?<p_data>\d*))? ?([X](?<x_data>[-]?\d+\.?\d*))? ?([Y](?<y_data>[-]?\d+\.?\d*))? ?([Z](?<z_data>[-]?\d+\.?\d*))? ?([F](?<f_data>\d+\.?\d*))? ?([E](?<e_data>[-]?\d+\.?\d*))?)? ?(?<string_data>[^;]*)?)? ?;?(?<comment>.*)?$/

      # Creates a {Line}
      # @param line [String] a line of GCode.
      # @return [false] if line is empty or doesn't match the evaluation expression.
      # @return [Line]
      def initialize(line)
        (line.nil? || line.empty?) ? @raw = '' : @raw = line
        @matches = @raw.match(GCODE_PATTERN)
        @f = @matches[:f_data].to_f unless @matches[:f_data].nil?
        @tool_number = command_number if !command_letter.nil? && command_letter == 'T'
      end

      # Checks if the given line is more than just a comment.
      # @return [Boolean] true if empty/invalid
      def empty?
        command.nil?
      end

      # Checks if the command in the line causes movement.
      # @return [Boolean] true if command moves printer, false otherwise.
      def is_move?
        command == RAPID_MOVE || command == CONTROLLED_MOVE
      end

      # Checks whether the line is a travel move or not.
      # @return [Boolean] true if line is a travel move, false otherwise.
      def travel_move?
        is_move? && e.nil?
      end

      # Checks whether the line is as extrusion move or not.
      # @return [Boolean] true if line is an extrusion move, false otherwise.
      def extrusion_move?
        is_move? && !e.nil? && e > 0
      end

      # Checks wether the line is a full home or not.
      # @return [Boolean] true if line is full home, false otherwise.
      def full_home?
        command == HOME && !x.nil? && !y.nil? && !z.nil?
      end

      # Returns the line, modified if multipliers are set and a line number is given.
      # @return [String] the line.
      def to_s(line_number = nil)
        return checksummed_line if line_number.nil? || !line_number.is_a?(Fixnum)
        return prefixed_line(line_number) if @extrusion_multiplier.nil? && @speed_multiplier.nil?

        new_f = multiplied_speed
        new_e = multiplied_extrusion

        x_string = !x.nil? ? " X#{x}" : ''
        y_string = !y.nil? ? " Y#{y}" : ''
        z_string = !z.nil? ? " Z#{z}" : ''
        e_string = !e.nil? ? " E#{new_e}" : ''
        f_string = !f.nil? ? " F#{new_f}" : ''
        string = !string_data.nil? ? " #{string_data}" : ''

        prefix_line("#{command}#{x_string}#{y_string}#{z_string}#{f_string}#{e_string}#{string}", line_number)
      end

## Line value functions

      # Striped version of the input GCode, or nil if not valid GCode
      # @return [String] striped line of GCode.
      # @return [nil] if no GCode was present .
      def line
        if @line.nil? && !@matches[:line].nil?
          @line = @matches[:line].strip
        else
          @line
        end
      end

      # The command in the line, nil if no command is present.
      # @return [String] command in the line.
      # @return [nil] if no command is present.
      def command
        @matches[:command]
      end

      # The command letter of the line, nil if no command is present.
      # @return [String] command letter of the line.
      # @return [nil] if no command is present.
      def command_letter
        @matches[:command_letter]
      end

      # The command number of the line, nil if no command is present.
      # @return [Fixnum] command number of the line.
      # @return [nil] if no command is present.
      def command_number
        if @command_number.nil? && !@matches[:command_number].nil?
          @command_number = @matches[:command_number].to_i
        else
          @command_number
        end
      end

      # The X value of the line, nil if no X value is present.
      # @return [Float] X value of the line.
      # @return [nil] if no X value is present.
      def x
        if @x.nil? && !@matches[:x_data].nil?
          @x = @matches[:x_data].to_f
        else
          @x
        end
      end

      # The Y value of the line, nil if no Y value is present.
      # @return [Float] Y value of the line.
      # @return [nil] if no Y value is present.
      def y
        if @y.nil? && !@matches[:y_data].nil?
          @y = @matches[:y_data].to_f
        else
          @y
        end
      end

      # The Z value of the line, nil if no Z value is present.
      # @return [Float] Z value of the line.
      # @return [nil] if no Z value is present.
      def z
        if @z.nil? && !@matches[:z_data].nil?
          @z = @matches[:z_data].to_f
        else
          @z
        end
      end

      # The E value of the line, nil if no E value is present.
      # @return [Float] E value of the line.
      # @return [nil] if no E value is present.
      def e
        if @e.nil? && !@matches[:e_data].nil?
          @e = @matches[:e_data].to_f
        else
          @e
        end
      end

      # The S value of the line, nil if no S value is present.
      # @return [Fixnum] S value of the line.
      # @return [nil] if no S value is present.
      def s
        if @s.nil? && !@matches[:s_data].nil?
          @s = @matches[:s_data].to_i
        else
          @s
        end
      end

      # The P value of the line, nil if no P value is present.
      # @return [Fixnum] P value of the line.
      # @return [nil] if no P value is present
      def p
        if @p.nil? && !@matches[:p_data].nil?
          @p = @matches[:p_data].to_i
        else
          @p
        end
      end

      # The string data of the line, nil if no string data is present.
      # @return [String] string data of the line.
      # @return [nil] if no string data is present
      def string_data
        if @string_data.nil? && (!@matches[:string_data].nil? || !@matches[:string_data].empty?)
          @string_data = @matches[:string_data].strip
        else
          @string_data
        end
      end

      # The comment of the line, nil if no comment is present.
      # @return [String] comment of the line.
      # @return [nil] if no comment is present
      def comment
        if @comment.nil? && !@matches[:comment].nil?
          @comment = @matches[:comment].strip
        else
          @comment
        end
      end

private

      def multiplied_extrusion
        if !e.nil? && valid_multiplier?(@extrusion_multiplier)
          return e * @extrusion_multiplier
        else
          e
        end
      end

      def multiplied_speed
        if travel_move? && valid_multiplier?(@travel_multiplier)
          return f * @travel_multiplier
        elsif extrusion_move? && valid_multiplier?(@speed_multiplier)
          return f * @speed_multiplier
        else
         return f
        end
      end

      def valid_multiplier?(multiplier)
        !multiplier.nil? && multiplier.is_a?(Numeric) && multiplier > 0
      end

      def get_checksum
        line.bytes.inject{|a,b| a^b}.to_s
      end

      def checksummed_line
        line+'*'+get_checksum
      end

      def prefixed_line(line_number)
        'N'+line_number.to_s+' '+checksummed_line
      end

    end
  end
end