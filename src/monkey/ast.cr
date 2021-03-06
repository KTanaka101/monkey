require "./token"

module Monkey::AST
  abstract class Node
    abstract def token_literal : String
    abstract def string : String
  end

  abstract class Statement < Node
    abstract def statement_node
  end

  abstract class Expression < Node
    abstract def expression_node
  end

  class Program < Node
    getter statements : Array(Statement)

    def initialize(@statements : Array(Statement))
    end

    def token_literal : String
      if @statements.size > 0
        @statements[0].token_literal
      else
        ""
      end
    end

    def string : String
      @statements.map(&.string).join
    end
  end

  class ExpressionStatement < Statement
    getter expression : Expression

    def initialize(@token : Token::Token, @expression : Expression)
    end

    def statement_node
    end

    def token_literal : String
      @token.literal
    end

    def string : String
      expression = @expression
      unless expression.nil?
        expression.string
      else
        ""
      end
    end
  end

  class LetStatement < Statement
    getter token : Token::Token, name : Identifier, value : Expression

    def initialize(@token : Token::Token, @name : Identifier, @value : Expression)
    end

    def statement_node
    end

    def token_literal : String
      @token.literal
    end

    def string : String
      out = "#{token_literal} #{@name.string} = "

      value = @value
      out += value.string unless value.nil?
      out += ";"

      out
    end
  end

  class ReturnStatement < Statement
    getter token : Token::Token, return_value : Expression

    def initialize(@token : Token::Token, @return_value : Expression)
    end

    def statement_node
    end

    def token_literal : String
      @token.literal
    end

    def string : String
      out = "#{token_literal} "

      return_value = @return_value
      out += return_value.string unless return_value.nil?
      out += ";"

      out
    end
  end

  class Identifier < Expression
    getter token : Token::Token, value : String

    def initialize(@token : Token::Token, @value : String)
    end

    def expression_node
    end

    def token_literal : String
      @token.literal
    end

    def string : String
      @value
    end
  end

  class IntegerLiteral < Expression
    getter token : Token::Token, value : Int64

    def initialize(@token : Token::Token, @value : Int64)
    end

    def expression_node
    end

    def token_literal : String
      @token.literal
    end

    def string : String
      @token.literal
    end
  end

  class PrefixExpression < Expression
    getter token : Token::Token, operator : String, right : Expression

    def initialize(@token : Token::Token, @operator : String, @right : Expression)
    end

    def expression_node
    end

    def token_literal : String
      @token.literal
    end

    def string : String
      "(#{@operator}#{@right.string})"
    end
  end

  class InfixExpression < Expression
    getter token : Token::Token, left : Expression, operator : String, right : Expression

    def initialize(@token : Token::Token, @left : Expression, @operator : String, @right : Expression)
    end

    def expression_node
    end

    def token_literal : String
      @token.literal
    end

    def string : String
      "(#{@left.string} #{@operator} #{@right.string})"
    end
  end

  class Boolean < Expression
    getter token : Token::Token, value : Bool

    def initialize(@token : Token::Token, @value : Bool)
    end

    def expression_node
    end

    def token_literal : String
      @token.literal
    end

    def string : String
      @token.literal
    end
  end

  class IfExpression < Expression
    getter token : Token::Token, condition : Expression, consequence : BlockStatement, alternative : BlockStatement?

    def initialize(@token : Token::Token, @condition : Expression, @consequence : BlockStatement, @alternative : BlockStatement?)
    end

    def expression_node
    end

    def token_literal : String
      @token.literal
    end

    def string : String
      s = "if#{@condition.string} #{@consequence.string}"

      alternative = @alternative
      if alternative
        s += "else #{alternative.string}"
      end

      s
    end
  end

  class BlockStatement < Statement
    getter token : Token::Token, statements : Array(Statement)

    def initialize(@token : Token::Token, @statements : Array(Statement))
    end

    def statement_node
    end

    def token_literal : String
      @token.literal
    end

    def string : String
      @statements.map(&.string).join
    end
  end

  class FunctionLiteral < Expression
    getter token : Token::Token, parameters : Array(Identifier), body : BlockStatement

    def initialize(@token : Token::Token, @parameters : Array(Identifier), @body : BlockStatement)
    end

    def expression_node
    end

    def token_literal : String
      @token.literal
    end

    def string : String
      "#{token_literal}(#{@parameters.map(&.string).join(", ")}) #{@body.string}"
    end
  end

  class CallExpression < Expression
    getter token : Token::Token, function : Expression, arguments : Array(Expression)

    def initialize(@token : Token::Token, @function : Expression, @arguments : Array(Expression))
    end

    def expression_node
    end

    def token_literal : String
      @token.literal
    end

    def string : String
      "#{function.string}(#{@arguments.map(&.string).join(", ")})"
    end
  end

  class StringLiteral < Expression
    getter token : Token::Token, value : String

    def initialize(@token : Token::Token, @value : String)
    end

    def expression_node
    end

    def token_literal : String
      @token.literal
    end

    def string : String
      @token.literal
    end
  end

  class ArrayLiteral < Expression
    getter token : Token::Token, elements : Array(Expression)

    def initialize(@token : Token::Token, @elements : Array(Expression))
    end

    def expression_node
    end

    def token_literal : String
      @token.literal
    end

    def string : String
      %([#{@elements.map(&.string).join(", ")}])
    end
  end

  class IndexExpression < Expression
    getter token, left, index

    def initialize(@token : Token::Token, @left : Expression, @index : Expression)
    end

    def expression_node
    end

    def token_literal : String
      @token.literal
    end

    def string : String
      "(#{@left.string}[#{@index.string}])"
    end
  end

  class HashLiteral < Expression
    getter token, pairs

    def initialize(@token : Token::Token, @pairs : Hash(Expression, Expression))
    end

    def expression_node
    end

    def token_literal : String
      @token.literal
    end

    def string : String
      hs_string = @pairs.map { |key, value|
        "#{key.string}:#{value.string}"
      }
        .join(", ")

      "{#{hs_string}}"
    end
  end
end
