require "./ast"
require "./lexer"
require "./token"

module Monkey::Parser
  class Parser
    getter lexer : Lexer::Lexer, cur_token : Token::Token, peek_token : Token::Token, errors : Array(String)

    enum Priority
      LOWEST      = 1
      EQUALS
      LESSGREATER
      SUM
      PRODUCT
      PREFIX
      CALL
      INDEX
    end

    PRECEDENCES = {
      Token::EQ       => Priority::EQUALS,
      Token::NOT_EQ   => Priority::EQUALS,
      Token::LT       => Priority::LESSGREATER,
      Token::GT       => Priority::LESSGREATER,
      Token::PLUS     => Priority::SUM,
      Token::MINUS    => Priority::SUM,
      Token::SLASH    => Priority::PRODUCT,
      Token::ASTERISK => Priority::PRODUCT,
      Token::LPAREN   => Priority::CALL,
      Token::LBRACKET => Priority::INDEX,
    }

    def initialize(@lexer, @errors = [] of String)
      @cur_token = Token::Token.new("dummy", "dummy")
      @peek_token = Token::Token.new("dummy", "dummy")
      next_token
      next_token
    end

    def next_token
      @cur_token = peek_token
      @peek_token = @lexer.next_token
    end

    def parse_program : AST::Program
      program = AST::Program.new([] of AST::Statement)

      while @cur_token.type != Token::EOF
        stmt = parse_statement
        program.statements.push(stmt) unless stmt.nil?
        next_token
      end

      program
    end

    def parse_statement : AST::Statement?
      case @cur_token.type
      when Token::LET
        parse_let_statement
      when Token::RETURN
        parse_return_statement
      else
        parse_expression_statement
      end
    end

    def parse_let_statement : AST::LetStatement?
      token = @cur_token

      return nil unless expect_peek?(Token::IDENT)

      name = AST::Identifier.new(@cur_token, @cur_token.literal)

      return nil unless expect_peek?(Token::ASSIGN)

      next_token

      value = parse_expression(Priority::LOWEST)
      return nil if value.nil?

      next_token if peek_token_is?(Token::SEMICOLON)

      AST::LetStatement.new(token, name, value)
    end

    def parse_return_statement : AST::ReturnStatement?
      token = @cur_token

      next_token

      return_value = parse_expression(Priority::LOWEST)
      return nil if return_value.nil?

      next_token if peek_token_is?(Token::SEMICOLON)

      AST::ReturnStatement.new(token, return_value)
    end

    def parse_expression_statement : AST::ExpressionStatement?
      token = @cur_token
      exp = parse_expression(Priority::LOWEST)
      return nil if exp.nil?

      next_token if peek_token_is?(Token::SEMICOLON)

      return AST::ExpressionStatement.new(token, exp)
    end

    def no_prefix_parse_fn_error(t : Token::TokenType)
      errors << "no prefix parse function for #{t} found"
    end

    def parse_expression(precedende : Priority) : AST::Expression?
      case @cur_token.type
      when Token::IDENT, Token::INT, Token::BANG, Token::MINUS, Token::TRUE, Token::FALSE, Token::LPAREN, Token::IF, Token::FUNCTION, Token::STRING, Token::LBRACKET, Token::LBRACE
      else
        no_prefix_parse_fn_error(@cur_token.type)
        return nil
      end

      left_exp = prefix_parse_fns(@cur_token.type)
      return nil if left_exp.nil?

      while !peek_token_is?(Token::SEMICOLON) && precedende < peek_precedence
        infix = infix_parse_fns(@peek_token.type)
        return left_exp if infix.nil?

        next_token

        left_exp = infix.call(left_exp)
        return nil if left_exp.nil?
      end

      left_exp
    end

    def parse_identifier : AST::Identifier
      AST::Identifier.new(@cur_token, @cur_token.literal)
    end

    def parse_integer_literal : AST::IntegerLiteral?
      value = @cur_token.literal.to_i64?
      if value.nil?
        @errors << "#could not parse #{@cur_token.literal} as integer"
        nil
      else
        AST::IntegerLiteral.new(@cur_token, value)
      end
    end

    def parse_bool_literal : AST::Boolean?
      AST::Boolean.new(@cur_token, cur_token_is?(Token::TRUE))
    end

    def parse_grouped_expression : AST::Expression?
      next_token

      exp = parse_expression(Priority::LOWEST)
      return nil unless expect_peek?(Token::RPAREN)

      exp
    end

    def parse_prefix_expression : AST::PrefixExpression?
      token = @cur_token
      ope = @cur_token.literal

      next_token

      right = parse_expression(Priority::PREFIX)
      if right
        AST::PrefixExpression.new(token, ope, right)
      else
        nil
      end
    end

    def parse_infix_expression(left : AST::Expression) : AST::InfixExpression?
      token = @cur_token
      ope = @cur_token.literal

      pre = cur_precedence
      next_token

      right = parse_expression(pre)

      if right
        AST::InfixExpression.new(token, left, ope, right)
      else
        nil
      end
    end

    def parse_if_expression : AST::IfExpression?
      token = @cur_token
      return nil unless expect_peek?(Token::LPAREN)

      next_token
      condition = parse_expression(Priority::LOWEST)

      return nil if condition.nil?

      return nil unless expect_peek?(Token::RPAREN)

      return nil unless expect_peek?(Token::LBRACE)

      consequence = parse_block_statement

      alternative = if peek_token_is?(Token::ELSE)
                      next_token

                      return nil unless expect_peek?(Token::LBRACE)

                      parse_block_statement
                    else
                      nil
                    end

      AST::IfExpression.new(token, condition, consequence, alternative)
    end

    def parse_block_statement : AST::BlockStatement
      token = @cur_token
      statements = [] of AST::Statement

      next_token

      while !cur_token_is?(Token::RBRACE) && !cur_token_is?(Token::EOF)
        stmt = parse_statement
        statements << stmt if stmt
        next_token
      end

      AST::BlockStatement.new(token, statements)
    end

    def parse_function_literal : AST::FunctionLiteral?
      token = @cur_token

      return nil unless expect_peek?(Token::LPAREN)

      params = parse_function_parameters

      return nil if params.nil?
      return nil unless expect_peek?(Token::LBRACE)

      body = parse_block_statement

      AST::FunctionLiteral.new(token, params, body)
    end

    def parse_function_parameters : Array(AST::Identifier)?
      identifiers = [] of AST::Identifier

      if peek_token_is?(Token::RPAREN)
        next_token
        return identifiers
      end

      next_token

      ident = AST::Identifier.new(@cur_token, @cur_token.literal)
      identifiers << ident

      while peek_token_is?(Token::COMMA)
        next_token
        next_token
        ident = AST::Identifier.new(@cur_token, @cur_token.literal)
        identifiers << ident
      end

      return nil unless expect_peek?(Token::RPAREN)

      identifiers
    end

    def parse_call_expression(function : AST::Expression) : AST::CallExpression?
      token = @cur_token
      arguments = parse_expression_list(Token::RPAREN)
      return nil if arguments.nil?

      AST::CallExpression.new(token, function, arguments)
    end

    def parse_expression_list(end_token : Token::TokenType) : Array(AST::Expression)?
      list = [] of AST::Expression

      if peek_token_is?(end_token)
        next_token
        return list
      end

      next_token
      exp = parse_expression(Priority::LOWEST)
      return nil if exp.nil?
      list << exp

      while peek_token_is?(Token::COMMA)
        next_token
        next_token
        exp = parse_expression(Priority::LOWEST)
        return nil if exp.nil?
        list << exp
      end

      return nil unless expect_peek?(end_token)

      list
    end

    def parse_string_literal : AST::StringLiteral
      AST::StringLiteral.new(@cur_token, @cur_token.literal)
    end

    def parse_array_literal : AST::ArrayLiteral?
      token = @cur_token
      elements = parse_expression_list(Token::RBRACKET)
      return nil if elements.nil?

      AST::ArrayLiteral.new(token, elements)
    end

    def parse_index_expression(left : AST::Expression) : AST::IndexExpression?
      token = @cur_token

      next_token

      index = parse_expression(Priority::LOWEST)
      return nil if index.nil?
      return nil unless expect_peek?(Token::RBRACKET)

      AST::IndexExpression.new(token, left, index)
    end

    def parse_hash_literal : AST::HashLiteral?
      token = @cur_token
      hash = {} of AST::Expression => AST::Expression

      until peek_token_is?(Token::RBRACE)
        next_token
        key = parse_expression(Priority::LOWEST)
        return nil if key.nil?

        return nil unless expect_peek?(Token::COLON)

        next_token
        value = parse_expression(Priority::LOWEST)
        return nil if value.nil?

        hash[key] = value

        return nil if !peek_token_is?(Token::RBRACE) && !expect_peek?(Token::COMMA)
      end

      return nil unless expect_peek?(Token::RBRACE)

      AST::HashLiteral.new(token, hash)
    end

    def cur_token_is?(token : Token::TokenType) : Bool
      @cur_token.type == token
    end

    def peek_token_is?(token : Token::TokenType) : Bool
      @peek_token.type == token
    end

    def expect_peek?(token : Token::TokenType) : Bool
      if peek_token_is?(token)
        next_token
        true
      else
        peek_error(token)
        false
      end
    end

    def peek_error(token : Token::TokenType)
      @errors.push("expected next token to be #{token}, got #{@peek_token.type} instead")
    end

    def prefix_parse_fns(key : Token::TokenType)
      case key
      when Token::IDENT
        parse_identifier
      when Token::INT
        parse_integer_literal
      when Token::BANG, Token::MINUS
        parse_prefix_expression
      when Token::TRUE, Token::FALSE
        parse_bool_literal
      when Token::LPAREN
        parse_grouped_expression
      when Token::IF
        parse_if_expression
      when Token::FUNCTION
        parse_function_literal
      when Token::STRING
        parse_string_literal
      when Token::LBRACKET
        parse_array_literal
      when Token::LBRACE
        parse_hash_literal
      end
    end

    def infix_parse_fns(key : Token::TokenType)
      case key
      when Token::PLUS, Token::MINUS, Token::SLASH, Token::ASTERISK, Token::EQ, Token::NOT_EQ, Token::LT, Token::GT
        ->parse_infix_expression(AST::Expression)
      when Token::LPAREN
        ->parse_call_expression(AST::Expression)
      when Token::LBRACKET
        ->parse_index_expression(AST::Expression)
      end
    end

    def peek_precedence
      pri = PRECEDENCES[@peek_token.type]?

      if pri
        pri
      else
        Priority::LOWEST
      end
    end

    def cur_precedence
      pri = PRECEDENCES[@cur_token.type]?

      if pri
        pri
      else
        Priority::LOWEST
      end
    end
  end
end
