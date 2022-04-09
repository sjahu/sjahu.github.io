# frozen_string_literal: true

module Jekyll
  module Tags
    class HighlightBlock < Liquid::Block
      # Replaces existing method
      def render_rouge(code)
        require "rouge"
        formatter = ::Rouge::Formatters::HTML.new
        if @highlight_options[:linenos]
          formatter = ::Rouge::Formatters::HTMLLineTable.new(
            formatter,
            {
              :css_class    => "highlight",
            }
          )
        end
        lexer = ::Rouge::Lexer.find_fancy(@lang, code) || Rouge::Lexers::PlainText
        formatter.format(lexer.lex(code))
      end
    end
  end
end
