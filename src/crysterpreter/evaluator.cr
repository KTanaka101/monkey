require "./ast"
require "./object"

module Crysterpreter::Evaluator
  TRUE  = Crysterpreter::Object::Boolean.new(true)
  FALSE = Crysterpreter::Object::Boolean.new(false)
  NULL  = Crysterpreter::Object::Null.new

  def self.eval(node : Crysterpreter::AST::Node) : Crysterpreter::Object::Object?
    case node
    when Crysterpreter::AST::Program
      eval_statements(node.statements)
    when Crysterpreter::AST::ExpressionStatement
      eval(node.expression)
    when Crysterpreter::AST::IntegerLiteral
      Crysterpreter::Object::Integer.new(node.value)
    when Crysterpreter::AST::Boolean
      node.value ? TRUE : FALSE
    when Crysterpreter::AST::PrefixExpression
      right = eval(node.right)
      return nil if right.nil?
      eval_prefix_expression(node.operator, right)
    else
      nil
    end
  end

  private def self.eval_statements(stmts : Array(Crysterpreter::AST::Statement)) : Crysterpreter::Object::Object?
    stmts.map { |statement|
      eval(statement)
    }.last
  end

  private def self.eval_prefix_expression(operator : String, right : Crysterpreter::Object::Object) : Crysterpreter::Object::Object
    case operator
    when "!"
      eval_bang_operator_expression(right)
    else
      NULL
    end
  end

  private def self.eval_bang_operator_expression(right : Crysterpreter::Object::Object) : Crysterpreter::Object::Object
    case right
    when TRUE
      FALSE
    when FALSE
      TRUE
    when NULL
      TRUE
    else
      FALSE
    end
  end
end
