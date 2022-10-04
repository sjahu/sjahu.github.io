class ImageTag < Liquid::Tag
  attr_reader :text, :src, :tokens
  
  def initialize(_tag_name, text, _tokens)
    super
    @text = text

    @src = text.split.first
    @tokens = text.split[1..]
  end

  def render(context)
    if css_class
      "<img src=\"#{src}\" class=\"#{css_class}\">"
    else
      "<img src=\"#{src}\">"
    end
  end

  def css_class
    tokens = text.split
    if tokens.include?("tiny")
      "tiny"
    elsif tokens.include?("small")
      "small"
    elsif tokens.include?("medium")
      "medium"
    elsif tokens.include?("large")
      "medium"
    end
  end
end

Liquid::Template.register_tag('image', ImageTag)