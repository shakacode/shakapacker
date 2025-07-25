require "nokogiri"

module HtmlTestHelpers
  # Compares script tags for semantic equality.
  # It ensures the number of script tags matches and then compares each tag's attributes, ignoring attribute order.
  #
  # @param rendered_html [String, ActiveSupport::SafeBuffer] The rendered HTML string containing script tags.
  # @param expected_html [String] The expected HTML string containing script tags.
  # @return [void] Asserts equality using RSpec's expect.
  def expect_script_tags_match(rendered_html, expected_html)
    rendered_doc = Nokogiri::HTML::DocumentFragment.parse(rendered_html.to_s)
    expected_doc = Nokogiri::HTML::DocumentFragment.parse(expected_html)

    rendered_scripts = rendered_doc.css("script")
    expected_scripts = expected_doc.css("script")

    expect(rendered_scripts.size).to eq(expected_scripts.size),
                                   "Mismatch in number of script tags: Expected #{expected_scripts.size}, but got #{rendered_scripts.size}.\n\n" \
                                     "Rendered script tags: \n#{rendered_scripts.map { |s| s.to_html }.join("\n")}\n\n" \
                                     "Expected script tags: \n#{expected_scripts.map { |s| s.to_html }.join("\n")}\n"

    rendered_scripts.each_with_index do |rendered_script, i|
      expected_script = expected_scripts[i]

      rendered_attrs = rendered_script.attributes.map { |name, attr| [name.to_s, attr.value] }.sort_by(&:first).to_h
      expected_attrs = expected_script.attributes.map { |name, attr| [name.to_s, attr.value] }.sort_by(&:first).to_h

      expect(rendered_attrs).to eq(expected_attrs),
                              "Mismatch in script tag #{i} (src: #{rendered_script['src'] || 'N/A'}):\n\n" \
                                "  Expected attributes: \n#{expected_attrs.inspect}\n\n" \
                                "  Rendered attributes: \n#{rendered_attrs.inspect}\n"
    end
  rescue StandardError => e
    fail "Error during script tag comparison: #{e.message}\n\n" \
           "Rendered HTML: \n#{rendered_html}\n\n" \
           "Expected HTML: \n#{expected_html}\n"
  end

  # Compares stylesheet link tags for semantic equality.
  # It ensures the number of link tags matches and then compares each tag's attributes, ignoring attribute order.
  #
  # @param rendered_html [String, ActiveSupport::SafeBuffer] The rendered HTML string containing stylesheet link tags.
  # @param expected_html [String] The expected HTML string containing stylesheet link tags.
  # @return [void] Asserts equality using RSpec's expect.
  def expect_stylesheet_link_tags_match(rendered_html, expected_html)
    rendered_doc = Nokogiri::HTML::DocumentFragment.parse(rendered_html.to_s)
    expected_doc = Nokogiri::HTML::DocumentFragment.parse(expected_html)

    rendered_links = rendered_doc.css("link[rel='stylesheet']")
    expected_links = expected_doc.css("link[rel='stylesheet']")

    expect(rendered_links.size).to eq(expected_links.size),
                                 "Mismatch in number of stylesheet link tags: Expected #{expected_links.size}, but got #{rendered_links.size}.\n\n" \
                                   "Actual stylesheet tags: \n#{rendered_links.map { |s| s.to_html }.join("\n")}\n\n" \
                                   "Expected stylesheet tags: \n#{expected_links.map { |s| s.to_html }.join("\n")}"

    rendered_links.each_with_index do |rendered_link, i|
      expected_link = expected_links[i]

      rendered_attrs = rendered_link.attributes.map { |name, attr| [name.to_s, attr.value] }.sort_by(&:first).to_h
      expected_attrs = expected_link.attributes.map { |name, attr| [name.to_s, attr.value] }.sort_by(&:first).to_h

      expect(rendered_attrs).to eq(expected_attrs),
                              "Mismatch in stylesheet link tag #{i} (href: #{rendered_link['href'] || 'N/A'}):\n\n" \
                                "  Expected attributes: \n#{expected_attrs.inspect}\n\n" \
                                "  Actual attributes:   \n#{rendered_attrs.inspect}\n"
    end
  rescue StandardError => e
    fail "Error during stylesheet link tag comparison: #{e.message}\n\n" \
           "Actual HTML: \n#{rendered_html}\n\n" \
           "Expected HTML: \n#{expected_html}"
  end
end
