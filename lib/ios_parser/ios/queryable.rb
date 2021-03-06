module IOSParser
  class IOS
    module Queryable
      def find_all(expr, &blk)
        _find_all(MatcherReader.query_expression(expr), &blk)
      end

      def find(expr, &blk)
        _find(MatcherReader.query_expression(expr), &blk)
      end

      def _find_all(expr, &blk)
        [].tap do |ret|
          commands.each do |command|
            if match_expr(expr, command)
              ret << command
              yield(command) if blk
            end

            ret.push(*command._find_all(expr, &blk))
          end
        end
      end

      def match_expr(expr, command)
        expr.each_pair.all? { |pred, arg| Matcher.send(pred, arg, command) }
      end

      def _find(expr, &blk)
        _find_all(expr) do |command|
          yield(command) if blk
          return command
        end
        nil
      end

      module MatcherReader
        class << self
          def query_expression(raw)
            case raw
            when Hash          then query_expression_hash(raw)
            when Proc          then { procedure: procedure(raw) }
            when Regexp        then { line: line(raw) }
            when String, Array then { starts_with: starts_with(raw) }
            else raise("Invalid query: #{raw.inspect}")
            end
          end
          alias parent query_expression
          alias any_child query_expression
          alias no_child query_expression

          def query_expression_hash(original)
            raw = original.dup
            raw.each_pair { |pred, arg| raw[pred] &&= send(pred, arg) }
            raw
          end

          def name(expr)
            expr
          end

          def starts_with(expr)
            case expr
            when String then expr.split
            when Array  then expr
            else raise("Invalid #{__method__} condition in query: #{expr}")
            end
          end
          alias contains starts_with
          alias ends_with starts_with

          def procedure(expr)
            unless expr.respond_to?(:call)
              raise("Invalid procedure in query: #{expr}")
            end
            expr
          end

          def line(expr)
            case expr
            when String, Regexp then expr
            when Array          then expr.join(' ')
            else raise("Invalid line condition in query: #{expr}")
            end
          end

          def array_wrap_and_map(expr)
            (expr.respond_to?(:map) && !expr.is_a?(Hash) ? expr : [expr])
              .map { |e| query_expression(e) }
          end
          alias any array_wrap_and_map
          alias all array_wrap_and_map
          alias none array_wrap_and_map
          alias not array_wrap_and_map
          alias not_all array_wrap_and_map

          def depth(expr)
            unless expr.is_a?(Integer) || (expr.is_a?(Range) &&
                                           expr.first.is_a?(Integer) &&
                                           expr.last.is_a?(Integer))
              raise("Invalid depth constraint in query: #{expr}")
            end
            expr
          end
        end # class << self
      end # module MatcherReader

      module Matcher
        class << self
          def name(expr, command)
            expr === command.name
          end

          def starts_with(req_ary, command)
            (0..req_ary.length - 1).all? do |i|
              compare_string_or_case(req_ary[i], command.args[i])
            end
          end

          def contains(req_ary, command)
            (0..command.args.length - req_ary.length).any? do |j|
              (0..req_ary.length - 1).all? do |i|
                compare_string_or_case(req_ary[i], command.args[i + j])
              end
            end
          end

          def ends_with(req_ary, command)
            (1..req_ary.length).all? do |i|
              compare_string_or_case(req_ary[-i], command.args[-1])
            end
          end

          def compare_string_or_case(a_object, b_object)
            case a_object
            when String
              a_object == b_object.to_s
            else
              a_object === b_object
            end
          end

          def procedure(expr, command)
            expr.call(command)
          end

          def line(expr, command)
            expr === command.line
          end

          def parent(expr, command)
            expr.each_pair.all? do |pred, arg|
              command.parent && send(pred, arg, command.parent)
            end
          end

          def any_child(expr, command)
            command.find(expr)
          end

          def no_child(expr, command)
            !command.find(expr)
          end

          def any(expressions, command)
            expressions.any? do |expr|
              expr.each_pair.any? do |pred, arg|
                send(pred, arg, command)
              end
            end
          end

          def all(expressions, command)
            expressions.all? do |expr|
              expr.each_pair.all? do |pred, arg|
                send(pred, arg, command)
              end
            end
          end

          def not_all(expressions, command)
            !expressions.all? { |expr| all([expr], command) }
          end
          alias not not_all

          def none(expressions, command)
            expressions.none? { |expr| all([expr], command) }
          end

          def depth(expr, command)
            case expr
            when Integer then depth_exact(expr, command)
            when Range   then depth_range(expr, command)
            end
          end

          def depth_exact(expr, command)
            _depth(expr, command) == expr
          end

          def depth_range(expr, command)
            _depth(expr.last, command) > expr.first
          end

          def _depth(max, command)
            level = 0
            ptr = command
            while ptr.parent
              ptr = ptr.parent
              level += 1
              return Float::MIN if level > max
            end
            level
          end
        end # class << self
      end # module Matcher
    end # module Queryable
  end # class IOS
end # module IOSParser
