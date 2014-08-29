require_relative 'ios/document'
require 'multi_json'

module IOSParser
  class IOS
    attr_accessor :lexer, :tokens, :source, :document

    def initialize(opts = {})
      defaults = { debug: false, parent: nil }

      @document = Document.new(nil)
      @debug  = opts[:debug]  || defaults[:debug]
      @parent = opts[:parent] || defaults[:parent]
      @lexer  = opts[:lexer]  || IOSParser::Lexer.new
    end

    def debug?
      @debug
    end

    def tokens
      @tokens ||= lexer.call(@source)
    end

    def call(source)
      unless source.respond_to? :each_char
        raise ArgumentError, "Provided configuration source is invalid."
      end
      @source = source
      @document.source = source
      until tokens.empty?
        @document.push(*section)
      end
      @document
    end

    def section(parent = nil)
      [].tap do |commands|
        until tokens.empty? || tokens.first.last == :DEDENT
          commands.push(command(parent, @document))
        end
        tokens.shift # discard :DEDENT
      end
    end

    def command(parent = nil, document = nil)
      pos = tokens.first.first
      opts = { args: arguments, parent: parent, document: document, pos: pos }

      Command.new(opts).tap do |cmd|
        cmd.commands = subsections(cmd)
      end
    end

    def arguments_to_discard
      [:INDENT, :DEDENT,
       :CERTIFICATE_BEGIN, :CERTIFICATE_END,
       :BANNER_BEGIN, :BANNER_END]
    end

    def arguments
      [].tap do |args|
        until tokens.empty? || tokens.first.last == :EOL
          _, arg = tokens.shift
          args << arg unless arguments_to_discard.include?(arg)
        end
        tokens.shift # discard :EOL
      end
    end

    def subsections(parent = nil)
      if !tokens.empty? && tokens.first.last == :INDENT
        tokens.shift # discard :INDENT
        section(parent)
      else
        []
      end
    end

    def dedent?
      tokens.first == :DEDENT && tokens.shift
    end
  end
end
