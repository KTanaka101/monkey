require "../spec_helper"
require "../../src/monkey/parser"

module Monkey::Parser
  describe Parser do
    describe "let statements" do
      {
        {"let x = 5", TestIdentifier.new("x"), 5},
        {"let x = 5;", TestIdentifier.new("x"), 5},
        {"let y = true;", TestIdentifier.new("y"), true},
        {"let foobar = y;", TestIdentifier.new("foobar"), TestIdentifier.new("y")},
      }.each do |input, expected_identifier, expected_value|
        it "for #{input}" do
          program = test_parse(input)

          program.statements.size.should eq 1
          stmt = program.statements[0]
          test_let_statement(stmt, expected_identifier)

          if stmt.is_a? AST::LetStatement
            val = stmt.value
            test_literal_expression(val, expected_value)
          end
        end
      end
    end

    describe "return statements" do
      {
        {"return 5", 5},
        {"return 5;", 5},
        {"return true;", true},
        {"return y;", TestIdentifier.new("y")},
      }.each do |input, expected|
        it "for #{input}" do
          program = test_parse(input)

          program.statements.size.should eq 1
          stmt = program.statements[0]
          test_return_statement(stmt, expected)
        end
      end
    end

    it "string" do
      program = AST::Program.new([
        AST::LetStatement.new(
          Token::Token.new(Token::LET, "let"),
          AST::Identifier.new(
            Token::Token.new(Token::IDENT, "myVar"),
            "myVar"
          ),
          AST::Identifier.new(
            Token::Token.new(Token::IDENT, "anotherVar"),
            "anotherVar"
          ),
        ),
      ] of AST::Statement)

      program.string.should eq "let myVar = anotherVar;"
    end

    it "identifier expression" do
      input = "foobar"

      program = test_parse(input)

      program.statements.size.should eq 1
      stmt = program.statements[0]

      stmt.should be_a AST::ExpressionStatement
      if stmt.is_a?(AST::ExpressionStatement)
        test_literal_expression(stmt.expression, TestIdentifier.new("foobar"))
      end
    end

    describe "integer literal" do
      {
        {"5", 5},
        {"5;", 5},
      }.each do |input, expected|
        it "for #{input}" do
          program = test_parse(input)

          program.statements.size.should eq 1
          stmt = program.statements[0]

          stmt.should be_a AST::ExpressionStatement
          if stmt.is_a?(AST::ExpressionStatement)
            test_literal_expression(stmt.expression, expected)
          end
        end
      end
    end

    describe "test boolean" do
      {
        {"true", true},
        {"true;", true},
        {"false;", false},
      }.each do |input, expected|
        it "for #{input}" do
          program = test_parse(input)

          program.statements.size.should eq 1
          stmt = program.statements[0]

          stmt.should be_a AST::ExpressionStatement
          if stmt.is_a?(AST::ExpressionStatement)
            test_literal_expression(stmt.expression, expected)
          end
        end
      end
    end

    describe "parsing prefix expressions" do
      {
        {"!5", "!", 5},
        {"!5;", "!", 5},
        {"-15;", "-", 15},
        {"!true;", "!", true},
        {"!false;", "!", false},
      }.each do |input, expected_operator, expected_value|
        it "for #{input}" do
          program = test_parse(input)

          program.statements.size.should eq 1

          stmt = program.statements[0]
          stmt.should be_a AST::ExpressionStatement
          if stmt.is_a?(AST::ExpressionStatement)
            exp = stmt.expression

            exp.should be_a AST::PrefixExpression
            if exp.is_a?(AST::PrefixExpression)
              exp.operator.should eq expected_operator
              test_literal_expression(exp.right, expected_value)
            end
          end
        end
      end
    end

    describe "parsing infix expressions" do
      {
        {"5 + 5", 5, "+", 5},
        {"5 + 5;", 5, "+", 5},
        {"5 - 5;", 5, "-", 5},
        {"5 * 5;", 5, "*", 5},
        {"5 / 5;", 5, "/", 5},
        {"5 > 5;", 5, ">", 5},
        {"5 < 5;", 5, "<", 5},
        {"5 == 5;", 5, "==", 5},
        {"5 != 5;", 5, "!=", 5},
        {"true == true;", true, "==", true},
        {"true != false;", true, "!=", false},
        {"false == false;", false, "==", false},
      }.each do |input, expected_left, expected_operator, expected_right|
        it "for #{input}" do
          program = test_parse(input)

          program.statements.size.should eq 1

          stmt = program.statements[0]
          stmt.should be_a AST::ExpressionStatement
          if stmt.is_a?(AST::ExpressionStatement)
            test_infix_expression(stmt.expression, expected_left, expected_operator, expected_right)
          end
        end
      end
    end

    describe "operator precedence parsing" do
      {
        {
          "-a * b",
          "((-a) * b)",
        },
        {
          "!-a",
          "(!(-a))",
        },
        {
          "a + b + c",
          "((a + b) + c)",
        },
        {
          "a + b - c",
          "((a + b) - c)",
        },
        {
          "a * b * c",
          "((a * b) * c)",
        },
        {
          "a * b / c",
          "((a * b) / c)",
        },
        {
          "a + b / c",
          "(a + (b / c))",
        },
        {
          "a + b * c + d / e - f",
          "(((a + (b * c)) + (d / e)) - f)",
        },
        {
          "3 + 4; -5 * 5",
          "(3 + 4)((-5) * 5)",
        },
        {
          "5 > 4 == 3 < 4",
          "((5 > 4) == (3 < 4))",
        },
        {
          "5 < 4 != 3 > 4",
          "((5 < 4) != (3 > 4))",
        },
        {
          "3 + 4 * 5 == 3 * 1 + 4 * 5",
          "((3 + (4 * 5)) == ((3 * 1) + (4 * 5)))",
        },
        {
          "true",
          "true",
        },
        {
          "false",
          "false",
        },
        {
          "3 > 5 == false",
          "((3 > 5) == false)",
        },
        {
          "3 < 5 == true",
          "((3 < 5) == true)",
        },
        {
          "1 + (2 + 3) + 4",
          "((1 + (2 + 3)) + 4)",
        },
        {
          "(5 + 5) * 2",
          "((5 + 5) * 2)",
        },
        {
          "2 / (5 + 5)",
          "(2 / (5 + 5))",
        },
        {
          "-(5 + 5)",
          "(-(5 + 5))",
        },
        {
          "!(true == true)",
          "(!(true == true))",
        },
        {
          "a + add(b * c) + d",
          "((a + add((b * c))) + d)",
        },
        {
          "add(a, b, 1, 2 * 3, 4 + 5, add(6, 7 * 8))",
          "add(a, b, 1, (2 * 3), (4 + 5), add(6, (7 * 8)))",
        },
        {
          "add(a + b + c * d / f  + g)",
          "add((((a + b) + ((c * d) / f)) + g))",
        },
        {
          "a * [1, 2, 3, 4][b * c] * d",
          "((a * ([1, 2, 3, 4][(b * c)])) * d)",
        },
        {
          "add(a * b[2], b[1], 2 * [1, 2][1])",
          "add((a * (b[2])), (b[1]), (2 * ([1, 2][1])))",
        },
      }.each do |input, expected|
        it "for #{input}" do
          program = test_parse(input)

          actual = program.string
          actual.should eq expected
        end
      end
    end

    it "if expression" do
      input = "if (x < y) { x }"

      program = test_parse(input)

      program.statements.size.should eq 1

      stmt = program.statements[0]
      stmt.should be_a AST::ExpressionStatement
      if stmt.is_a?(AST::ExpressionStatement)
        exp = stmt.expression
        exp.should be_a AST::IfExpression
        if exp.is_a?(AST::IfExpression)
          test_infix_expression(exp.condition, TestIdentifier.new("x"), "<", TestIdentifier.new("y"))
          exp.consequence.statements.size.should eq 1
          consequence = exp.consequence.statements[0]

          consequence.should be_a AST::ExpressionStatement
          if consequence.is_a?(AST::ExpressionStatement)
            test_indentifier(consequence.expression, TestIdentifier.new("x"))

            exp.alternative.should be_nil
          end
        end
      end
    end

    describe "if else expression" do
      {
        "if (x < y) { x } else { y }",
        "if (x < y) { x; } else { y; }",
      }.each do |input|
        it "for #{input}" do
          program = test_parse(input)

          program.statements.size.should eq 1

          stmt = program.statements[0]
          stmt.should be_a AST::ExpressionStatement
          if stmt.is_a?(AST::ExpressionStatement)
            exp = stmt.expression
            exp.should be_a AST::IfExpression
            if exp.is_a?(AST::IfExpression)
              test_infix_expression(exp.condition, TestIdentifier.new("x"), "<", TestIdentifier.new("y"))
              exp.consequence.statements.size.should eq 1
              consequence = exp.consequence.statements[0]

              consequence.should be_a AST::ExpressionStatement
              if consequence.is_a?(AST::ExpressionStatement)
                test_indentifier(consequence.expression, TestIdentifier.new("x"))
              end

              alt = exp.alternative
              alt.should be_a AST::BlockStatement
              if alt.is_a?(AST::BlockStatement)
                alt.statements.size.should eq 1
                alternative = alt.statements[0]

                alternative.should be_a AST::ExpressionStatement
                if alternative.is_a?(AST::ExpressionStatement)
                  test_indentifier(alternative.expression, TestIdentifier.new("y"))
                end
              end
            end
          end
        end
      end
    end

    describe "function literal parsing" do
      {
        "fn(x, y) { x + y }",
        "fn(x, y) { x + y; }",
      }.each do |input|
        it "for #{input}" do
          program = test_parse(input)

          program.statements.size.should eq 1

          stmt = program.statements[0]
          stmt.should be_a AST::ExpressionStatement
          if stmt.is_a?(AST::ExpressionStatement)
            exp = stmt.expression
            exp.should be_a AST::FunctionLiteral
            if exp.is_a?(AST::FunctionLiteral)
              exp.parameters.size.should eq 2

              test_literal_expression(exp.parameters[0], TestIdentifier.new("x"))
              test_literal_expression(exp.parameters[1], TestIdentifier.new("y"))

              exp.body.statements.size.should eq 1
              body_stmt = exp.body.statements[0]
              body_stmt.should be_a AST::ExpressionStatement
              if body_stmt.is_a?(AST::ExpressionStatement)
                test_infix_expression(body_stmt.expression, TestIdentifier.new("x"), "+", TestIdentifier.new("y"))
              end
            end
          end
        end
      end
    end

    describe "function parameter parsing" do
      {
        {"fn() {};", [] of TestIdentifier},
        {"fn(x) {};", [TestIdentifier.new("x")]},
        {"fn(x, y, z) {};", [TestIdentifier.new("x"), TestIdentifier.new("y"), TestIdentifier.new("z")]},
      }.each do |input, expected_params|
        it "for #{input}" do
          program = test_parse(input)

          stmt = program.statements[0]
          if stmt.is_a?(AST::ExpressionStatement)
            function = stmt.expression

            function.should be_a AST::FunctionLiteral
            if function.is_a?(AST::FunctionLiteral)
              function.parameters.size.should eq expected_params.size

              expected_params.each_with_index do |ident, i|
                test_literal_expression(function.parameters[i], ident)
              end
            end
          end
        end
      end
    end

    it "call expression parsing" do
      input = "add(1, 2 * 3, 4 + 5);"

      program = test_parse(input)

      program.statements.size.should eq 1

      stmt = program.statements[0]
      stmt.should be_a AST::ExpressionStatement
      if stmt.is_a?(AST::ExpressionStatement)
        exp = stmt.expression
        exp.should be_a AST::CallExpression
        if exp.is_a?(AST::CallExpression)
          test_indentifier(exp.function, TestIdentifier.new("add"))
          exp.arguments.size.should eq 3
          test_literal_expression(exp.arguments[0], 1)
          test_infix_expression(exp.arguments[1], 2, "*", 3)
          test_infix_expression(exp.arguments[2], 4, "+", 5)
        end
      end
    end

    it "string literal expression" do
      input = %("hello world")

      program = test_parse(input)

      program.statements.size.should eq 1
      stmt = program.statements[0]

      stmt.should be_a AST::ExpressionStatement
      if stmt.is_a?(AST::ExpressionStatement)
        literal = stmt.expression
        literal.should be_a AST::StringLiteral
        if literal.is_a?(AST::StringLiteral)
          literal.value.should eq "hello world"
        end
      end
    end

    describe "parsing array literals" do
      {
        {
          "[1, 2 * 2, 3 + 3]",
          { {1}, {2, "*", 2}, {3, "+", 3} },
        },
      }.each do |input, expected|
        it "for #{input}" do
          program = test_parse(input)

          program.statements.size.should eq 1
          stmt = program.statements[0]

          stmt.should be_a AST::ExpressionStatement
          if stmt.is_a?(AST::ExpressionStatement)
            array = stmt.expression
            array.should be_a AST::ArrayLiteral
            if array.is_a?(AST::ArrayLiteral)
              array.elements.size.should eq 3
              array.elements.each_with_index do |element, i|
                expect = expected[i]
                if expect.is_a?(Tuple(Int32))
                  test_literal_expression(element, *expect)
                else
                  test_infix_expression(element, *expect)
                end
              end
            end
          end
        end
      end
    end

    describe "parsing index expressions" do
      {
        {
          "myArray[1 + 1]",
          {TestIdentifier.new("myArray"), {1, "+", 1}},
        },
      }.each do |input, expected|
        it "for #{input}" do
          program = test_parse(input)

          program.statements.size.should eq 1
          stmt = program.statements[0]

          stmt.should be_a AST::ExpressionStatement
          if stmt.is_a?(AST::ExpressionStatement)
            index = stmt.expression
            index.should be_a AST::IndexExpression
            if index.is_a?(AST::IndexExpression)
              test_indentifier(index.left, expected[0])

              expect = expected[1]
              if expect.is_a?(Tuple(Int32))
                test_literal_expression(index.index, *expect)
              else
                test_infix_expression(index.index, *expect)
              end
            end
          end
        end
      end
    end

    describe "parsing hash literal" do
      {
        {
          %({}),
          {} of String => String, # type is dummy
        },
        {
          %({"one": 1, "two": 2, "three": 3}),
          {"one" => 1, "two" => 2, "three" => 3},
        },
        {
          %({"one": 0 + 1, "two": 10 - 8, "three": 15 / 5}),
          {"one" => {0, "+", 1}, "two" => {10, "-", 8}, "three" => {15, "/", 5}},
        },
        {
          %({1: 111, 2: "b", 3: true}),
          {"1" => 111, "2" => "b", "3" => true},
        },
        {
          %({true: 1, false: "abc"}),
          {"true" => 1, "false" => "abc"},
        },
      }.each do |input, expected|
        it "for #{input}" do
          program = test_parse(input)

          program.statements.size.should eq 1
          stmt = program.statements[0]

          stmt.should be_a AST::ExpressionStatement
          if stmt.is_a?(AST::ExpressionStatement)
            test_hash_literal(stmt.expression, expected)
          end
        end
      end
    end
  end
end

record TestIdentifier, value : String

def check_parser_errors(parser : Monkey::Parser::Parser)
  errors = parser.errors
  return if errors.size == 0

  puts("parser has #{errors.size} errors")
  errors.each do |error|
    puts "parser error: #{error}"
  end

  "test".should eq "fail."
end

def test_parse(input : String) : Monkey::AST::Program
  l = Monkey::Lexer::Lexer.new(input)
  parser = Monkey::Parser::Parser.new(l)
  program = parser.parse_program
  check_parser_errors(parser)
  program
end

def test_let_statement(stmt : Monkey::AST::Statement, name : TestIdentifier)
  stmt.should be_a Monkey::AST::LetStatement
  if stmt.is_a?(Monkey::AST::LetStatement)
    stmt.token_literal.should eq "let"
    stmt.name.value.should eq name.value
    stmt.name.token_literal.should eq name.value
  end
end

def test_return_statement(stmt : Monkey::AST::Statement, return_value)
  stmt.should be_a Monkey::AST::ReturnStatement
  if stmt.is_a?(Monkey::AST::ReturnStatement)
    stmt.token_literal.should eq "return"
    test_literal_expression(stmt.return_value, return_value)
  end
end

def test_integer_literal(exp, value : Int64)
  exp.should be_a Monkey::AST::IntegerLiteral
  if exp.is_a?(Monkey::AST::IntegerLiteral)
    exp.value.should eq value
    exp.token_literal.should eq value.to_s
  end
end

def test_indentifier(exp, identifier : TestIdentifier)
  exp.should be_a Monkey::AST::Identifier
  if exp.is_a?(Monkey::AST::Identifier)
    exp.value.should eq identifier.value
    exp.token_literal.should eq identifier.value
  end
end

def test_boolean_literal(exp, value : Bool)
  exp.should be_a Monkey::AST::Boolean
  if exp.is_a?(Monkey::AST::Boolean)
    exp.value.should eq value
    exp.token_literal.should eq value.to_s
  end
end

def test_string_literal(exp, value : String)
  exp.should be_a Monkey::AST::StringLiteral
  if exp.is_a?(Monkey::AST::StringLiteral)
    exp.value.should eq value
    exp.token_literal.should eq value.to_s
  end
end

def test_hash_literal(exp, expected : Hash)
  exp.should be_a Monkey::AST::HashLiteral
  return unless exp.is_a?(Monkey::AST::HashLiteral)

  exp.pairs.size.should eq expected.size

  expected_keys = expected.keys
  exp.pairs.each_with_index do |(key, value), i|
    expected_value = expected[key.string]?
    expected_value.should_not be_nil
    next if expected_value.nil?
    test_literal_expression(value, expected_value)
  end
end

def test_literal_expression(exp, expected)
  case expected
  when Int32
    test_integer_literal(exp, Int64.new(expected))
  when Int64
    test_integer_literal(exp, expected)
  when String
    test_string_literal(exp, expected)
  when TestIdentifier
    test_indentifier(exp, expected)
  when Bool
    test_boolean_literal(exp, expected)
  when Tuple
    test_infix_expression(exp, *expected)
  else
    expected.should eq "type of exp not handled."
  end
end

def test_infix_expression(exp, left, operator, right)
  exp.should be_a Monkey::AST::InfixExpression
  if exp.is_a?(Monkey::AST::InfixExpression)
    test_literal_expression(exp.left, left)
    exp.operator.should eq operator
    test_literal_expression(exp.right, right)
  end
end
