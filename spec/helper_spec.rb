module ActionView::TestCase::Behavior
  attr_accessor :request

  describe "Shakapacker::Helper" do
    let(:application_stylesheet_chunks) { %w[/packs/1-c20632e7baf2c81200d3.chunk.css /packs/application-k344a6d59eef8632c9d1.chunk.css] }
    let(:hello_stimulus_stylesheet_chunks) { %w[/packs/1-c20632e7baf2c81200d3.chunk.css /packs/hello_stimulus-k344a6d59eef8632c9d1.chunk.css] }

    before :each do
      extend Shakapacker::Helper
      extend ActionView::Helpers
      extend ActionView::Helpers::AssetTagHelper
      extend ActionView::TestCase::Behavior

      @request = Class.new do
        def send_early_hints(links) end
        def base_url
          "https://example.com"
        end
      end.new
      @javascript_pack_tag_loaded = nil
    end

    it "#asset_pack_path generates correct path" do
      expect(asset_pack_path("bootstrap.js")).to eq "/packs/bootstrap-300631c4f0e0f9c865bc.js"
      expect(asset_pack_path("bootstrap.css")).to eq "/packs/bootstrap-c38deda30895059837cf.css"
    end

    it "#asset_pack_url generates correct url" do
      expect(asset_pack_url("bootstrap.js")).to eq "https://example.com/packs/bootstrap-300631c4f0e0f9c865bc.js"
      expect(asset_pack_url("bootstrap.css")).to eq "https://example.com/packs/bootstrap-c38deda30895059837cf.css"
    end

    it "#image_pack_path generates correct path" do
      expect(image_pack_path("application.png")).to eq "/packs/application-k344a6d59eef8632c9d1.png"
      expect(image_pack_path("image.jpg")).to eq "/packs/static/image-c38deda30895059837cf.jpg"
      expect(image_pack_path("static/image.jpg")).to eq "/packs/static/image-c38deda30895059837cf.jpg"
      expect(image_pack_path("nested/image.jpg")).to eq "/packs/static/nested/image-c38deda30895059837cf.jpg"
      expect(image_pack_path("static/nested/image.jpg")).to eq "/packs/static/nested/image-c38deda30895059837cf.jpg"
    end

    it "#image_pack_url generates correct path" do
      expect(image_pack_url("application.png")).to eq "https://example.com/packs/application-k344a6d59eef8632c9d1.png"
      expect(image_pack_url("image.jpg")).to eq "https://example.com/packs/static/image-c38deda30895059837cf.jpg"
      expect(image_pack_url("static/image.jpg")).to eq "https://example.com/packs/static/image-c38deda30895059837cf.jpg"
      expect(image_pack_url("nested/image.jpg")).to eq "https://example.com/packs/static/nested/image-c38deda30895059837cf.jpg"
      expect(image_pack_url("static/nested/image.jpg")).to eq "https://example.com/packs/static/nested/image-c38deda30895059837cf.jpg"
    end

    it "#image_pack_tag generates correct tags" do
      expect(image_pack_tag("application.png", size: "16x10", alt: "Edit Entry")).to eq "<img alt=\"Edit Entry\" src=\"/packs/application-k344a6d59eef8632c9d1.png\" width=\"16\" height=\"10\" />"
      expect(image_pack_tag("image.jpg", size: "16x10", alt: "Edit Entry")).to eq "<img alt=\"Edit Entry\" src=\"/packs/static/image-c38deda30895059837cf.jpg\" width=\"16\" height=\"10\" />"
      expect(image_pack_tag("static/image.jpg", size: "16x10", alt: "Edit Entry")).to eq "<img alt=\"Edit Entry\" src=\"/packs/static/image-c38deda30895059837cf.jpg\" width=\"16\" height=\"10\" />"
      expect(image_pack_tag("nested/image.jpg", size: "16x10", alt: "Edit Entry")).to eq "<img alt=\"Edit Entry\" src=\"/packs/static/nested/image-c38deda30895059837cf.jpg\" width=\"16\" height=\"10\" />"
      expect(image_pack_tag("static/nested/image.jpg", size: "16x10", alt: "Edit Entry")).to eq "<img alt=\"Edit Entry\" src=\"/packs/static/nested/image-c38deda30895059837cf.jpg\" width=\"16\" height=\"10\" />"
      expect(image_pack_tag("static/image.jpg", srcset: { "static/image-2x.jpg" => "2x" })).to eq "<img srcset=\"/packs/static/image-2x-7cca48e6cae66ec07b8e.jpg 2x\" src=\"/packs/static/image-c38deda30895059837cf.jpg\" />"
    end

    it "#favicon_pack_tag generates correct tags" do
      expect(favicon_pack_tag("application.png", rel: "apple-touch-icon", type: "image/png")).to eq "<link rel=\"apple-touch-icon\" type=\"image/png\" href=\"/packs/application-k344a6d59eef8632c9d1.png\" />"
      expect(favicon_pack_tag("mb-icon.png", rel: "apple-touch-icon", type: "image/png")).to eq "<link rel=\"apple-touch-icon\" type=\"image/png\" href=\"/packs/static/mb-icon-c38deda30895059837cf.png\" />"
      expect(favicon_pack_tag("static/mb-icon.png", rel: "apple-touch-icon", type: "image/png")).to eq "<link rel=\"apple-touch-icon\" type=\"image/png\" href=\"/packs/static/mb-icon-c38deda30895059837cf.png\" />"
      expect(favicon_pack_tag("nested/mb-icon.png", rel: "apple-touch-icon", type: "image/png")).to eq "<link rel=\"apple-touch-icon\" type=\"image/png\" href=\"/packs/static/nested/mb-icon-c38deda30895059837cf.png\" />"
      expect(favicon_pack_tag("static/nested/mb-icon.png", rel: "apple-touch-icon", type: "image/png")).to eq "<link rel=\"apple-touch-icon\" type=\"image/png\" href=\"/packs/static/nested/mb-icon-c38deda30895059837cf.png\" />"
    end

    it "#preload_pack_asset generates correct tag" do
      if self.class.method_defined?(:preload_link_tag)
        expect(preload_pack_asset("fonts/fa-regular-400.woff2")).to eq %(<link rel="preload" href="/packs/fonts/fa-regular-400-944fb546bd7018b07190a32244f67dc9.woff2" as="font" type="font/woff2" crossorigin="anonymous">)
      else
        expect { preload_pack_asset("fonts/fa-regular-400.woff2") }.to raise_error "You need Rails >= 5.2 to use this tag."
      end
    end

    it "#javascript_pack_tag generates correct tags" do
      expected = <<~HTML.chomp
        <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js" defer="defer"></script>
        <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js" defer="defer"></script>
        <script src="/packs/application-k344a6d59eef8632c9d1.js" defer="defer"></script>
        <script src="/packs/bootstrap-300631c4f0e0f9c865bc.js" defer="defer"></script>
      HTML

      expect(javascript_pack_tag("application", "bootstrap")).to eq expected
    end

    it "#javascript_pack_tag generates correct tags by passing `defer: false`" do
      expected = <<~HTML.chomp
        <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js"></script>
        <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js"></script>
        <script src="/packs/application-k344a6d59eef8632c9d1.js"></script>
        <script src="/packs/bootstrap-300631c4f0e0f9c865bc.js"></script>
      HTML

      expect(javascript_pack_tag("application", "bootstrap", defer: false)).to eq expected
    end

    it "#javascript_pack_tag generates correct appended tag" do
      append_javascript_pack_tag("bootstrap", defer: false)

      expected = <<~HTML.chomp
        <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js" defer="defer"></script>
        <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js" defer="defer"></script>
        <script src="/packs/application-k344a6d59eef8632c9d1.js" defer="defer"></script>
        <script src="/packs/bootstrap-300631c4f0e0f9c865bc.js"></script>
      HTML

      expect(javascript_pack_tag("application")).to eq expected
    end

    it "#javascript_pack_tag generates correct prepended tag" do
      append_javascript_pack_tag("bootstrap")
      prepend_javascript_pack_tag("main")

      expected = <<~HTML.chomp
        <script src="/packs/main-e323a53c7f30f5d53cbb.js" defer="defer"></script>
        <script src="/packs/bootstrap-300631c4f0e0f9c865bc.js" defer="defer"></script>
        <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js" defer="defer"></script>
        <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js" defer="defer"></script>
        <script src="/packs/application-k344a6d59eef8632c9d1.js" defer="defer"></script>
      HTML

      expect(javascript_pack_tag("application")).to eq expected
    end

    it "#append_javascript_pack_tag raises error if called after calling #javascript_pack_tag" do
      expected_error_message = \
        "You can only call append_javascript_pack_tag before javascript_pack_tag helper. " +
        "Please refer to https://github.com/shakacode/shakapacker/blob/master/README.md#view-helper-append_javascript_pack_tag-prepend_javascript_pack_tag-and-append_stylesheet_pack_tag for the usage guide"

      expect {
        javascript_pack_tag("application")
        append_javascript_pack_tag("bootstrap", defer: false)
      }.to raise_error(expected_error_message)
    end

    it "#prepend_javascript_pack_tag raises error if called after calling #javascript_pack_tag" do
      expected_error_message = \
        "You can only call prepend_javascript_pack_tag before javascript_pack_tag helper. " +
        "Please refer to https://github.com/shakacode/shakapacker/blob/master/README.md#view-helper-append_javascript_pack_tag-prepend_javascript_pack_tag-and-append_stylesheet_pack_tag for the usage guide"

      expect {
        javascript_pack_tag("application")
        prepend_javascript_pack_tag("bootstrap", defer: false)
      }.to raise_error(expected_error_message)
    end

    it "#javascript_pack_tag generates correct tags by passing `defer: true`" do
      expected = <<~HTML.chomp
        <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js" defer="defer"></script>
        <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js" defer="defer"></script>
        <script src="/packs/application-k344a6d59eef8632c9d1.js" defer="defer"></script>
      HTML

      expect(javascript_pack_tag("application", defer: true)).to eq expected
    end

    it "#javascript_pack_tag generates correct tags by passing symbol" do
      expected = <<~HTML.chomp
        <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js" defer="defer"></script>
        <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js" defer="defer"></script>
        <script src="/packs/application-k344a6d59eef8632c9d1.js" defer="defer"></script>
      HTML

      expect(javascript_pack_tag(:application)).to eq expected
    end

    it "#javascript_pack_tag rases error on multiple invocations" do
      expected_error_message = "To prevent duplicated chunks on the page, you should call javascript_pack_tag only once on the page. " +
      "Please refer to https://github.com/shakacode/shakapacker/blob/master/README.md#view-helpers-javascript_pack_tag-and-stylesheet_pack_tag for the usage guide"

      expect {
        javascript_pack_tag(:application)
        javascript_pack_tag(:bootstrap)
      }.to raise_error(expected_error_message)
    end

    it "#stylesheet_pack_tag generates correct link tag with string arguments" do
      expected = (application_stylesheet_chunks + hello_stimulus_stylesheet_chunks)
        .uniq
        .map { |chunk| stylesheet_link_tag(chunk) }
        .join("\n")

      expect(stylesheet_pack_tag("application", "hello_stimulus")).to eq expected
    end

    it "#stylesheet_pack_tag generates correct link tag with symbol arguments" do
      expected = (application_stylesheet_chunks + hello_stimulus_stylesheet_chunks)
        .uniq
        .map { |chunk| stylesheet_link_tag(chunk) }
        .join("\n")

      expect(stylesheet_pack_tag(:application, :hello_stimulus)).to eq expected
    end

    it "#stylesheet_pack_tag generates correct link tag with mixed arguments" do
      expected = (application_stylesheet_chunks)
        .map { |chunk| stylesheet_link_tag(chunk, media: "all") }
        .join("\n")

      expect(stylesheet_pack_tag("application", media: "all")).to eq expected
    end

    it "#stylesheet_pack_tag allows multiple invocations" do
      app_style = stylesheet_pack_tag(:application)
      stimulus_style = stylesheet_pack_tag(:hello_stimulus)

      expect(app_style).to eq application_stylesheet_chunks.map { |chunk| stylesheet_link_tag(chunk) }.join("\n")

      expect(stimulus_style).to eq hello_stimulus_stylesheet_chunks.map { |chunk| stylesheet_link_tag(chunk) }.join("\n")

      expect {
        stylesheet_pack_tag(:application)
        stylesheet_pack_tag(:hello_stimulus)
      }.to_not raise_error
    end

    it "#stylesheet_pack_tag appends" do
      append_stylesheet_pack_tag(:hello_stimulus)

      expect(stylesheet_pack_tag(:application)).to eq \
        (application_stylesheet_chunks + hello_stimulus_stylesheet_chunks).uniq.map { |chunk| stylesheet_link_tag(chunk) }.join("\n")
    end

    it "#stylesheet_pack_tag appends duplicate" do
      append_stylesheet_pack_tag(:hello_stimulus)
      append_stylesheet_pack_tag(:application)

      expect(stylesheet_pack_tag(:application)).to eq \
        (application_stylesheet_chunks + hello_stimulus_stylesheet_chunks).uniq.map { |chunk| stylesheet_link_tag(chunk) }.join("\n")
    end

    it "#stylesheet_pack_tag supports multiple invocations with different media attr" do
      app_style = stylesheet_pack_tag(:application)
      app_style_with_media = stylesheet_pack_tag(:application, media: "print")
      hello_stimulus_style_with_media = stylesheet_pack_tag(:hello_stimulus, media: "all")

      expect(app_style).to eq application_stylesheet_chunks.map { |chunk| stylesheet_link_tag(chunk) }.join("\n")
      expect(app_style_with_media).to eq application_stylesheet_chunks.map { |chunk| stylesheet_link_tag(chunk, media: "print") }.join("\n")
      expect(hello_stimulus_style_with_media).to eq hello_stimulus_stylesheet_chunks.map { |chunk| stylesheet_link_tag(chunk, media: "all") }.join("\n")
    end
  end
end
