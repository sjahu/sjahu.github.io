class ImageTag < Liquid::Tag
  attr_reader :text, :src
  
  def initialize(_tag_name, text, _tokens)
    super
    @text = text

    @src = text.split.first
  end

  def render(_context)
    "<img src=\"#{src}\" #{"class=\"#{css_class}\"" if css_class}>"
  end

  def css_class
    text.split.intersection(["tiny", "small", "medium", "large", "huge"]).last
  end
end

Liquid::Template.register_tag("image", ImageTag)
