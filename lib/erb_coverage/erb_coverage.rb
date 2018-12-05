require 'coverage'

module ErbCoverage
  class ViewCoverage
    def self.instance
      @instance ||= new
    end

    def self.line_is_code(path, lineno, non_executable)
      instance.line_is_code(path, lineno, non_executable)
    end

    def self.visit(tracepoint)
      instance.visit tracepoint
    end

    def self.result
      instance.result
    end

    def initialize
      @visits = {}
    end

    def line_is_code(path, lineno, non_executable)
      visits_to_path("#{Rails.application.root.to_s}/#{path}")[lineno-1] ||= non_executable ? nil : 0
    end

    def visit(tracepoint)
      vtp = visits_to_path(tracepoint.path)
      vtp[tracepoint.lineno-1] += 1 if vtp[tracepoint.lineno-1]
    end

    def result
      @visits.dup
    end

    private

    def visits_to_path(path)
      @visits[path] ||= []
    end
  end

  def self.start
    Coverage.instance_exec do
      singleton_class.send :alias_method, :_result, :result
      def self.result
        temp_result = _result.dup
        ErbCoverage::ViewCoverage.result.each {|filename, coverage| temp_result[filename] = coverage }
        temp_result
      end
    end

    trace = TracePoint.trace(:line) do |tp|
      if tp.path[0, VIEW_FILENAME_PATTERN.length] == VIEW_FILENAME_PATTERN
        ErbCoverage::ViewCoverage.visit tp
      end
    end

    ::ActionView::Template::Handlers::ERB.class_eval do
      def call(template) # copied from Rails.../action_view/templates/handlers/erb.rb
        template_source = template.source.dup.force_encoding(Encoding::ASCII_8BIT)
        erb = template_source.gsub(::ActionView::Template::Handlers::ERB::ENCODING_TAG, "")
        encoding = $2
        erb.force_encoding valid_encoding(template.source.dup, encoding)
        erb.encode!
        self.class.erb_implementation.new(
          erb,
          escape: (self.class.escape_whitelist.include? template.type),
          trim: (self.class.erb_trim_mode == "-"),
          path: template.inspect
        ).src
      end
    end

    ::ActionView::Template::Handlers::ERB::Erubi.class_eval do
      alias :_initialize :initialize
      def initialize(input, properties)
        @path = properties[:path]
        _initialize input, properties
      end

      alias :_add_text :add_text
      def add_text(text)
        unless text.empty? || text == "\n"
          line_is_code
          newline @newline_pending
          add_newline text
        end
        _add_text text
      end

      alias :_add_expression :add_expression
      def add_expression(indicator, code)
        eat_pending_newlines
        line_is_code
        _add_expression indicator, code
        add_newline code
      end

      alias :_add_code :add_code
      def add_code(code)
        eat_pending_newlines
        line_is_code non_executable?(code)
        _add_code code
        add_newline code
      end

      private

      def newline(count = 1)
        @lineno = lineno + count
      end

      def add_newline(string)
        newline string.scan(/\n/).length
      end

      def lineno
        @lineno || 1
      end

      def eat_pending_newlines
        line_is_code unless @newline_pending.zero?
        newline @newline_pending
      end

      def line_is_code(non_executable = false)
        ErbCoverage::ViewCoverage.line_is_code @path, lineno, non_executable
      end

      def non_executable?(code)
        return true if code =~ /\s*#/
        return true if [['end'], ['else']].include? code.scan(/\w+/)
        if code =~ /when\s+\S+(\sthen\s*\S+)?/
          return false if code =~ /\sthen\s*\S+/
          return true
        end
        false
      end
    end
  end
end
