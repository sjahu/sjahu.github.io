class FigureBlock < Liquid::Block
  attr_reader :text, :src

  def initialize(_tag_name, text, _tokens)
    super
    @text = text

    @src = text.split.first
  end

  def render(context)
    "<figure #{"class=\"#{css_class}\"" if css_class}>\n" + 
    "  #{Liquid::Template.parse("{% image #{text} %}").render(context)}\n" +
    "  <figcaption>#{super.strip}</figcaption>\n" +
    "</figure>\n"
  end

  def css_class
    text.split.intersection(["tiny", "small", "medium", "large", "huge"]).last
  end

  def blank?
    false # render the block even if it's blank
  end
end

Liquid::Template.register_tag("figure", FigureBlock)
