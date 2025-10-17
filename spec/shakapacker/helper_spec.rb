require_relative "spec_helper_initializer"

module ActionView::TestCase::Behavior
  attr_accessor :request

  describe "Shakapacker::Helper" do
    context "without integrity hashes" do
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
        @javascript_pack_tag_queue = nil
        @stylesheet_pack_tag_queue = nil
      end

      it "#asset_pack_path generates the correct path" do
        expect(asset_pack_path("bootstrap.js")).to eq "/packs/bootstrap-300631c4f0e0f9c865bc.js"
        expect(asset_pack_path("bootstrap.css")).to eq "/packs/bootstrap-c38deda30895059837cf.css"
      end

      it "#asset_pack_url generates the correct url" do
        expect(asset_pack_url("bootstrap.js")).to eq "https://example.com/packs/bootstrap-300631c4f0e0f9c865bc.js"
        expect(asset_pack_url("bootstrap.css")).to eq "https://example.com/packs/bootstrap-c38deda30895059837cf.css"
      end

      it "#image_pack_path generates the correct path" do
        expect(image_pack_path("application.png")).to eq "/packs/application-k344a6d59eef8632c9d1.png"
        expect(image_pack_path("image.jpg")).to eq "/packs/static/image-c38deda30895059837cf.jpg"
        expect(image_pack_path("static/image.jpg")).to eq "/packs/static/image-c38deda30895059837cf.jpg"
        expect(image_pack_path("nested/image.jpg")).to eq "/packs/static/nested/image-c38deda30895059837cf.jpg"
        expect(image_pack_path("static/nested/image.jpg")).to eq "/packs/static/nested/image-c38deda30895059837cf.jpg"
      end

      it "#image_pack_url generates the correct path" do
        expect(image_pack_url("application.png")).to eq "https://example.com/packs/application-k344a6d59eef8632c9d1.png"
        expect(image_pack_url("image.jpg")).to eq "https://example.com/packs/static/image-c38deda30895059837cf.jpg"
        expect(image_pack_url("static/image.jpg")).to eq "https://example.com/packs/static/image-c38deda30895059837cf.jpg"
        expect(image_pack_url("nested/image.jpg")).to eq "https://example.com/packs/static/nested/image-c38deda30895059837cf.jpg"
        expect(image_pack_url("static/nested/image.jpg")).to eq "https://example.com/packs/static/nested/image-c38deda30895059837cf.jpg"
      end

      it "#image_pack_tag generates the correct tags" do
        expect(image_pack_tag("application.png", size: "16x10", alt: "Edit Entry")).to eq "<img alt=\"Edit Entry\" src=\"/packs/application-k344a6d59eef8632c9d1.png\" width=\"16\" height=\"10\" />"
        expect(image_pack_tag("image.jpg", size: "16x10", alt: "Edit Entry")).to eq "<img alt=\"Edit Entry\" src=\"/packs/static/image-c38deda30895059837cf.jpg\" width=\"16\" height=\"10\" />"
        expect(image_pack_tag("static/image.jpg", size: "16x10", alt: "Edit Entry")).to eq "<img alt=\"Edit Entry\" src=\"/packs/static/image-c38deda30895059837cf.jpg\" width=\"16\" height=\"10\" />"
        expect(image_pack_tag("nested/image.jpg", size: "16x10", alt: "Edit Entry")).to eq "<img alt=\"Edit Entry\" src=\"/packs/static/nested/image-c38deda30895059837cf.jpg\" width=\"16\" height=\"10\" />"
        expect(image_pack_tag("static/nested/image.jpg", size: "16x10", alt: "Edit Entry")).to eq "<img alt=\"Edit Entry\" src=\"/packs/static/nested/image-c38deda30895059837cf.jpg\" width=\"16\" height=\"10\" />"
        expect(image_pack_tag("static/image.jpg", srcset: { "static/image-2x.jpg" => "2x" })).to eq "<img srcset=\"/packs/static/image-2x-7cca48e6cae66ec07b8e.jpg 2x\" src=\"/packs/static/image-c38deda30895059837cf.jpg\" />"
      end

      it "#favicon_pack_tag generates the correct tags" do
        expect(favicon_pack_tag("application.png", rel: "apple-touch-icon", type: "image/png")).to eq "<link rel=\"apple-touch-icon\" type=\"image/png\" href=\"/packs/application-k344a6d59eef8632c9d1.png\" />"
        expect(favicon_pack_tag("mb-icon.png", rel: "apple-touch-icon", type: "image/png")).to eq "<link rel=\"apple-touch-icon\" type=\"image/png\" href=\"/packs/static/mb-icon-c38deda30895059837cf.png\" />"
        expect(favicon_pack_tag("static/mb-icon.png", rel: "apple-touch-icon", type: "image/png")).to eq "<link rel=\"apple-touch-icon\" type=\"image/png\" href=\"/packs/static/mb-icon-c38deda30895059837cf.png\" />"
        expect(favicon_pack_tag("nested/mb-icon.png", rel: "apple-touch-icon", type: "image/png")).to eq "<link rel=\"apple-touch-icon\" type=\"image/png\" href=\"/packs/static/nested/mb-icon-c38deda30895059837cf.png\" />"
        expect(favicon_pack_tag("static/nested/mb-icon.png", rel: "apple-touch-icon", type: "image/png")).to eq "<link rel=\"apple-touch-icon\" type=\"image/png\" href=\"/packs/static/nested/mb-icon-c38deda30895059837cf.png\" />"
      end

      it "#preload_pack_asset generates the correct tag" do
        if self.class.method_defined?(:preload_link_tag)
          expect(preload_pack_asset("fonts/fa-regular-400.woff2")).to eq %(<link rel="preload" href="/packs/fonts/fa-regular-400-944fb546bd7018b07190a32244f67dc9.woff2" as="font" type="font/woff2" crossorigin="anonymous">)
        else
          expect { preload_pack_asset("fonts/fa-regular-400.woff2") }.to raise_error "You need Rails >= 5.2 to use this tag."
        end
      end

      it "#javascript_pack_tag generates the correct tags" do
        expected = <<~HTML.chomp
          <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js" defer="defer"></script>
          <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js" defer="defer"></script>
          <script src="/packs/application-k344a6d59eef8632c9d1.js" defer="defer"></script>
          <script src="/packs/bootstrap-300631c4f0e0f9c865bc.js" defer="defer"></script>
        HTML

        expect(javascript_pack_tag("application", "bootstrap")).to eq expected
      end

      it "#javascript_pack_tag generates the correct tags when passing `defer: false`" do
        expected = <<~HTML.chomp
          <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js"></script>
          <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js"></script>
          <script src="/packs/application-k344a6d59eef8632c9d1.js"></script>
          <script src="/packs/bootstrap-300631c4f0e0f9c865bc.js"></script>
        HTML

        expect(javascript_pack_tag("application", "bootstrap", defer: false)).to eq expected
      end

      it "#javascript_pack_tag generates the correct appended tag" do
        append_javascript_pack_tag("bootstrap", defer: false)

        expected = <<~HTML.chomp
          <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js" defer="defer"></script>
          <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js" defer="defer"></script>
          <script src="/packs/application-k344a6d59eef8632c9d1.js" defer="defer"></script>
          <script src="/packs/bootstrap-300631c4f0e0f9c865bc.js"></script>
        HTML

        expect(javascript_pack_tag("application")).to eq expected
      end

      it "#javascript_pack_tag generates the correct prepended tag" do
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

      it "#append_javascript_pack_tag raises an error if called after calling #javascript_pack_tag" do
        expected_error_message = \
          "You can only call append_javascript_pack_tag before javascript_pack_tag helper. " +
          "Please refer to https://github.com/shakacode/shakapacker/blob/main/README.md#view-helper-append_javascript_pack_tag-prepend_javascript_pack_tag-and-append_stylesheet_pack_tag for the usage guide"

        expect {
          javascript_pack_tag("application")
          append_javascript_pack_tag("bootstrap", defer: false)
        }.to raise_error(expected_error_message)
      end

      it "#prepend_javascript_pack_tag raises an error if called after calling #javascript_pack_tag" do
        expected_error_message = \
          "You can only call prepend_javascript_pack_tag before javascript_pack_tag helper. " +
          "Please refer to https://github.com/shakacode/shakapacker/blob/main/README.md#view-helper-append_javascript_pack_tag-prepend_javascript_pack_tag-and-append_stylesheet_pack_tag for the usage guide"

        expect {
          javascript_pack_tag("application")
          prepend_javascript_pack_tag("bootstrap", defer: false)
        }.to raise_error(expected_error_message)
      end

      it "#javascript_pack_tag generates the correct tags when passing `defer: true`" do
        expected = <<~HTML.chomp
          <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js" defer="defer"></script>
          <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js" defer="defer"></script>
          <script src="/packs/application-k344a6d59eef8632c9d1.js" defer="defer"></script>
        HTML

        expect(javascript_pack_tag("application", defer: true)).to eq expected
      end

      it "#javascript_pack_tag generates the correct tags when passing a symbol" do
        expected = <<~HTML.chomp
          <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js" defer="defer"></script>
          <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js" defer="defer"></script>
          <script src="/packs/application-k344a6d59eef8632c9d1.js" defer="defer"></script>
        HTML

        expect(javascript_pack_tag(:application)).to eq expected
      end

      it "#javascript_pack_tag raises error on multiple invocations" do
        expected_error_message = "To prevent duplicated chunks on the page, you should call javascript_pack_tag only once on the page. " +
                                 "Please refer to https://github.com/shakacode/shakapacker/blob/main/README.md#view-helpers-javascript_pack_tag-and-stylesheet_pack_tag for the usage guide"

        expect {
          javascript_pack_tag(:application)
          javascript_pack_tag(:bootstrap)
        }.to raise_error(expected_error_message)
      end

      it "#javascript_pack_tag generates the correct tags when passing `async: true`" do
        expected = <<~HTML.chomp
          <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js" async="async"></script>
          <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js" async="async"></script>
          <script src="/packs/application-k344a6d59eef8632c9d1.js" async="async"></script>
        HTML

        expect(javascript_pack_tag("application", async: true)).to eq expected
      end

      it "#javascript_pack_tag generates the correct tags when passing both `defer: true` and `async: true`" do
        # When both async and defer are specified, async takes precedence per HTML5 spec
        expected = <<~HTML.chomp
          <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js" async="async"></script>
          <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js" async="async"></script>
          <script src="/packs/application-k344a6d59eef8632c9d1.js" async="async"></script>
        HTML

        expect(javascript_pack_tag("application", defer: true, async: true)).to eq expected
      end

      it "#append_javascript_pack_tag supports the async attribute" do
        append_javascript_pack_tag("bootstrap", async: true)

        expected = <<~HTML.chomp
          <script src="/packs/bootstrap-300631c4f0e0f9c865bc.js" async="async"></script>
          <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js" defer="defer"></script>
          <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js" defer="defer"></script>
          <script src="/packs/application-k344a6d59eef8632c9d1.js" defer="defer"></script>
        HTML

        expect(javascript_pack_tag("application")).to eq expected
      end

      it "#prepend_javascript_pack_tag supports the async attribute" do
        prepend_javascript_pack_tag("main", async: true)

        expected = <<~HTML.chomp
          <script src="/packs/main-e323a53c7f30f5d53cbb.js" async="async"></script>
          <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js" defer="defer"></script>
          <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js" defer="defer"></script>
          <script src="/packs/application-k344a6d59eef8632c9d1.js" defer="defer"></script>
        HTML

        expect(javascript_pack_tag("application")).to eq expected
      end

      it "#stylesheet_pack_tag generates the correct link tag with string arguments" do
        expected = (application_stylesheet_chunks + hello_stimulus_stylesheet_chunks)
                     .uniq
                     .map { |chunk| stylesheet_link_tag(chunk) }
                     .join("\n")

        expect(stylesheet_pack_tag("application", "hello_stimulus")).to eq expected
      end

      it "#stylesheet_pack_tag generates the correct link tag with symbol arguments" do
        expected = (application_stylesheet_chunks + hello_stimulus_stylesheet_chunks)
                     .uniq
                     .map { |chunk| stylesheet_link_tag(chunk) }
                     .join("\n")

        expect(stylesheet_pack_tag(:application, :hello_stimulus)).to eq expected
      end

      it "#stylesheet_pack_tag generates the correct link tag with mixed arguments" do
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

      it "#stylesheet_pack_tag appends tags" do
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

      it "#stylesheet_pack_tag supports multiple invocations with different media attr values" do
        app_style = stylesheet_pack_tag(:application)
        app_style_with_media = stylesheet_pack_tag(:application, media: "print")
        hello_stimulus_style_with_media = stylesheet_pack_tag(:hello_stimulus, media: "all")

        expect(app_style).to eq application_stylesheet_chunks.map { |chunk| stylesheet_link_tag(chunk) }.join("\n")
        expect(app_style_with_media).to eq application_stylesheet_chunks.map { |chunk| stylesheet_link_tag(chunk, media: "print") }.join("\n")
        expect(hello_stimulus_style_with_media).to eq hello_stimulus_stylesheet_chunks.map { |chunk| stylesheet_link_tag(chunk, media: "all") }.join("\n")
      end

      describe "#send_pack_early_hints" do
        it "returns nil to avoid rendering output" do
          allow(Shakapacker.config).to receive(:early_hints).and_return({ enabled: true, include_css: true, include_js: true })
          expect(send_pack_early_hints("application")).to be_nil
        end

        it "requires explicit pack names (no automatic queue collection)" do
          allow(Shakapacker.config).to receive(:early_hints).and_return({ enabled: true, include_css: true, include_js: true })
          # Even if packs were queued, calling without arguments should not send hints
          append_javascript_pack_tag("application")
          expect(@request).not_to receive(:send_early_hints)
          expect(send_pack_early_hints).to be_nil  # No pack names provided
        end

        it "does not call send_early_hints when early hints are disabled" do
          allow(Shakapacker.config).to receive(:early_hints).and_return({ enabled: false, include_css: true, include_js: true })
          expect(@request).not_to receive(:send_early_hints)
          send_pack_early_hints("application")
        end

        it "does not call send_early_hints when request does not support it" do
          # Create a request object without send_early_hints method
          @request = Class.new do
            def base_url
              "https://example.com"
            end
          end.new

          allow(Shakapacker.config).to receive(:early_hints).and_return({ enabled: true, include_css: true, include_js: true })
          # Should not raise an error and should not call send_early_hints
          expect { send_pack_early_hints("application") }.not_to raise_error
        end

        it "sends early hints for JavaScript and CSS when enabled" do
          allow(Shakapacker.config).to receive(:early_hints).and_return({ enabled: true, include_css: true, include_js: true })
          expect(@request).to receive(:send_early_hints) do |headers|
            expect(headers).to have_key("Link")
            link_headers = headers["Link"]
            expect(link_headers).to match(%r{</packs/vendors~application~bootstrap-c20632e7baf2c81200d3\.chunk\.js>})
            expect(link_headers).to match(%r{</packs/vendors~application-e55f2aae30c07fb6d82a\.chunk\.js>})
            expect(link_headers).to match(%r{</packs/application-k344a6d59eef8632c9d1\.js>})
            expect(link_headers).to match(%r{</packs/1-c20632e7baf2c81200d3\.chunk\.css>})
            expect(link_headers).to match(%r{</packs/application-k344a6d59eef8632c9d1\.chunk\.css>})
          end
          send_pack_early_hints("application")
        end

        it "sends early hints only for JavaScript when CSS is disabled" do
          allow(Shakapacker.config).to receive(:early_hints).and_return({ enabled: true, include_css: false, include_js: true })
          expect(@request).to receive(:send_early_hints) do |headers|
            expect(headers).to have_key("Link")
            link_headers = headers["Link"]
            expect(link_headers).to match(%r{</packs/vendors~application~bootstrap-c20632e7baf2c81200d3\.chunk\.js>})
            expect(link_headers).not_to match(/\.css>/)
          end
          send_pack_early_hints("application")
        end

        it "sends early hints only for CSS when JavaScript is disabled" do
          allow(Shakapacker.config).to receive(:early_hints).and_return({ enabled: true, include_css: true, include_js: false })
          expect(@request).to receive(:send_early_hints) do |headers|
            expect(headers).to have_key("Link")
            link_headers = headers["Link"]
            expect(link_headers).to match(%r{</packs/1-c20632e7baf2c81200d3\.chunk\.css>})
            expect(link_headers).not_to match(/\.js>/)
          end
          send_pack_early_hints("application")
        end

        it "allows per-call options to override config" do
          allow(Shakapacker.config).to receive(:early_hints).and_return({ enabled: true, include_css: false, include_js: true })
          expect(@request).to receive(:send_early_hints) do |headers|
            expect(headers).to have_key("Link")
            link_headers = headers["Link"]
            expect(link_headers).to match(%r{</packs/1-c20632e7baf2c81200d3\.chunk\.css>})
          end
          send_pack_early_hints("application", include_css: true)
        end

        it "sends early hints for multiple packs" do
          allow(Shakapacker.config).to receive(:early_hints).and_return({ enabled: true, include_css: true, include_js: true })
          expect(@request).to receive(:send_early_hints) do |headers|
            expect(headers).to have_key("Link")
            link_headers = headers["Link"]
            # Verify assets from both application and bootstrap packs are included
            expect(link_headers).to match(%r{</packs/vendors~application~bootstrap-c20632e7baf2c81200d3\.chunk\.js>})
            expect(link_headers).to match(%r{</packs/application-k344a6d59eef8632c9d1\.js>})
            expect(link_headers).to match(%r{</packs/bootstrap-300631c4f0e0f9c865bc\.js>})
            expect(link_headers).to match(%r{</packs/1-c20632e7baf2c81200d3\.chunk\.css>})
            expect(link_headers).to match(%r{</packs/application-k344a6d59eef8632c9d1\.chunk\.css>})
          end
          send_pack_early_hints("application", "bootstrap")
        end

        it "gracefully handles missing entries" do
          allow(Shakapacker.config).to receive(:early_hints).and_return({ enabled: true, include_css: true, include_js: true })
          expect(@request).not_to receive(:send_early_hints)
          send_pack_early_hints("nonexistent_pack")
        end

        it "sends headers in correct Rails format with Link key and comma-delimited string value" do
          allow(Shakapacker.config).to receive(:early_hints).and_return({ enabled: true, include_css: true, include_js: true })
          expect(@request).to receive(:send_early_hints) do |headers|
            # Verify the structure matches Rails/Puma expectations: {"Link" => "comma, delimited, string"}
            expect(headers).to be_a(Hash)
            expect(headers.keys).to eq(["Link"])
            expect(headers["Link"]).to be_a(String)
            expect(headers["Link"]).not_to be_empty
            # Should contain multiple comma-separated Link headers
            links = headers["Link"].split(", ")
            expect(links.length).to be > 0
            # Each link should be a properly formatted Link header
            links.each do |link|
              expect(link).to match(/^<[^>]+>;\s*rel=preload/)
            end
          end
          send_pack_early_hints("application")
        end
      end

    end

    context "with integrity hashes" do
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
        @javascript_pack_tag_queue = nil
        @stylesheet_pack_tag_queue = nil

        allow(Shakapacker.config).to receive(:integrity).and_return({ enabled: true, cross_origin: "anonymous" })
      end

      it "#asset_pack_path generates the correct path" do
        expect(asset_pack_path("bootstrap_with_integrity.js")).to eq "/packs/bootstrap_with_integrity-300631c4f0e0f9c865bc.js"
        expect(asset_pack_path("bootstrap_with_integrity.css")).to eq "/packs/bootstrap_with_integrity-c38deda30895059837cf.css"
      end

      it "#asset_pack_url generates the correct url" do
        expect(asset_pack_url("bootstrap_with_integrity.js")).to eq "https://example.com/packs/bootstrap_with_integrity-300631c4f0e0f9c865bc.js"
        expect(asset_pack_url("bootstrap_with_integrity.css")).to eq "https://example.com/packs/bootstrap_with_integrity-c38deda30895059837cf.css"
      end

      it "#image_pack_path generates the correct path" do
        expect(image_pack_path("application_with_integrity.png")).to eq "/packs/application_with_integrity-k344a6d59eef8632c9d1.png"
        expect(image_pack_path("image_with_integrity.jpg")).to eq "/packs/static/image_with_integrity-c38deda30895059837cf.jpg"
        expect(image_pack_path("static/image_with_integrity.jpg")).to eq "/packs/static/image_with_integrity-c38deda30895059837cf.jpg"
        expect(image_pack_path("nested/image_with_integrity.jpg")).to eq "/packs/static/nested/image_with_integrity-c38deda30895059837cf.jpg"
        expect(image_pack_path("static/nested/image_with_integrity.jpg")).to eq "/packs/static/nested/image_with_integrity-c38deda30895059837cf.jpg"
      end

      it "#image_pack_url generates the correct path" do
        expect(image_pack_url("application_with_integrity.png")).to eq "https://example.com/packs/application_with_integrity-k344a6d59eef8632c9d1.png"
        expect(image_pack_url("image_with_integrity.jpg")).to eq "https://example.com/packs/static/image_with_integrity-c38deda30895059837cf.jpg"
        expect(image_pack_url("static/image_with_integrity.jpg")).to eq "https://example.com/packs/static/image_with_integrity-c38deda30895059837cf.jpg"
        expect(image_pack_url("nested/image_with_integrity.jpg")).to eq "https://example.com/packs/static/nested/image_with_integrity-c38deda30895059837cf.jpg"
        expect(image_pack_url("static/nested/image_with_integrity.jpg")).to eq "https://example.com/packs/static/nested/image_with_integrity-c38deda30895059837cf.jpg"
      end

      it "#image_pack_tag generates the correct tags" do
        expect(image_pack_tag("application_with_integrity.png", size: "16x10", alt: "Edit Entry")).to eq "<img alt=\"Edit Entry\" src=\"/packs/application_with_integrity-k344a6d59eef8632c9d1.png\" width=\"16\" height=\"10\" />"
        expect(image_pack_tag("image_with_integrity.jpg", size: "16x10", alt: "Edit Entry")).to eq "<img alt=\"Edit Entry\" src=\"/packs/static/image_with_integrity-c38deda30895059837cf.jpg\" width=\"16\" height=\"10\" />"
        expect(image_pack_tag("static/image_with_integrity.jpg", size: "16x10", alt: "Edit Entry")).to eq "<img alt=\"Edit Entry\" src=\"/packs/static/image_with_integrity-c38deda30895059837cf.jpg\" width=\"16\" height=\"10\" />"
        expect(image_pack_tag("nested/image_with_integrity.jpg", size: "16x10", alt: "Edit Entry")).to eq "<img alt=\"Edit Entry\" src=\"/packs/static/nested/image_with_integrity-c38deda30895059837cf.jpg\" width=\"16\" height=\"10\" />"
        expect(image_pack_tag("static/nested/image_with_integrity.jpg", size: "16x10", alt: "Edit Entry")).to eq "<img alt=\"Edit Entry\" src=\"/packs/static/nested/image_with_integrity-c38deda30895059837cf.jpg\" width=\"16\" height=\"10\" />"
        expect(image_pack_tag("static/image_with_integrity.jpg", srcset: { "static/image-2x_with_integrity.jpg" => "2x" })).to eq "<img srcset=\"/packs/static/image-2x_with_integrity-7cca48e6cae66ec07b8e.jpg 2x\" src=\"/packs/static/image_with_integrity-c38deda30895059837cf.jpg\" />"
      end

      it "#favicon_pack_tag generates the correct tags" do
        expect(favicon_pack_tag("application_with_integrity.png", rel: "apple-touch-icon", type: "image/png")).to eq "<link rel=\"apple-touch-icon\" type=\"image/png\" href=\"/packs/application_with_integrity-k344a6d59eef8632c9d1.png\" />"
        expect(favicon_pack_tag("mb-icon_with_integrity.png", rel: "apple-touch-icon", type: "image/png")).to eq "<link rel=\"apple-touch-icon\" type=\"image/png\" href=\"/packs/static/mb-icon_with_integrity-c38deda30895059837cf.png\" />"
        expect(favicon_pack_tag("static/mb-icon_with_integrity.png", rel: "apple-touch-icon", type: "image/png")).to eq "<link rel=\"apple-touch-icon\" type=\"image/png\" href=\"/packs/static/mb-icon_with_integrity-c38deda30895059837cf.png\" />"
        expect(favicon_pack_tag("nested/mb-icon_with_integrity.png", rel: "apple-touch-icon", type: "image/png")).to eq "<link rel=\"apple-touch-icon\" type=\"image/png\" href=\"/packs/static/nested/mb-icon_with_integrity-c38deda30895059837cf.png\" />"
        expect(favicon_pack_tag("static/nested/mb-icon_with_integrity.png", rel: "apple-touch-icon", type: "image/png")).to eq "<link rel=\"apple-touch-icon\" type=\"image/png\" href=\"/packs/static/nested/mb-icon_with_integrity-c38deda30895059837cf.png\" />"
      end

      it "#preload_pack_asset generates the correct tag" do
        if self.class.method_defined?(:preload_link_tag)
          expect(preload_pack_asset("fonts/fa-regular-400_with_integrity.woff2")).to eq %(<link rel="preload" href="/packs/fonts/fa-regular-400_with_integrity-944fb546bd7018b07190a32244f67dc9.woff2" as="font" type="font/woff2" crossorigin="anonymous">)
        else
          expect { preload_pack_asset("fonts/fa-regular-400_with_integrity.woff2") }.to raise_error "You need Rails >= 5.2 to use this tag."
        end
      end

      it "#javascript_pack_tag generates the correct tags" do
        expected = <<~HTML.chomp
            <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
            <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
            <script src="/packs/application-k344a6d59eef8632c9d1.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
            <script src="/packs/bootstrap-300631c4f0e0f9c865bc.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
        HTML

        expect_script_tags_match(javascript_pack_tag("application_with_integrity", "bootstrap_with_integrity"), expected)
      end

      it "#javascript_pack_tag generates the correct tags when passing `defer: false`" do
        expected = <<~HTML.chomp
          <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js" crossorigin="anonymous" integrity="sha384-hash"></script>
          <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js" crossorigin="anonymous" integrity="sha384-hash"></script>
          <script src="/packs/application-k344a6d59eef8632c9d1.js" crossorigin="anonymous" integrity="sha384-hash"></script>
          <script src="/packs/bootstrap-300631c4f0e0f9c865bc.js" crossorigin="anonymous" integrity="sha384-hash"></script>
        HTML

        expect_script_tags_match(javascript_pack_tag("application_with_integrity", "bootstrap_with_integrity", defer: false), expected)
      end

      it "#javascript_pack_tag generates the correct appended tag" do
        append_javascript_pack_tag("bootstrap_with_integrity", defer: false)

        expected = <<~HTML.chomp
          <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
          <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
          <script src="/packs/application-k344a6d59eef8632c9d1.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
          <script src="/packs/bootstrap-300631c4f0e0f9c865bc.js" crossorigin="anonymous" integrity="sha384-hash"></script>
        HTML

        expect_script_tags_match(javascript_pack_tag("application_with_integrity"), expected)
      end

      it "#javascript_pack_tag generates the correct prepended tag" do
        append_javascript_pack_tag("bootstrap_with_integrity")
        prepend_javascript_pack_tag("main_with_integrity")

        expected = <<~HTML.chomp
          <script src="/packs/main-e323a53c7f30f5d53cbb.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
          <script src="/packs/bootstrap-300631c4f0e0f9c865bc.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
          <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
          <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
          <script src="/packs/application-k344a6d59eef8632c9d1.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
        HTML

        expect_script_tags_match(javascript_pack_tag("application_with_integrity"), expected)
      end

      it "#append_javascript_pack_tag raises an error if called after calling #javascript_pack_tag" do
        expected_error_message = \
          "You can only call append_javascript_pack_tag before javascript_pack_tag helper. " +
          "Please refer to https://github.com/shakacode/shakapacker/blob/main/README.md#view-helper-append_javascript_pack_tag-prepend_javascript_pack_tag-and-append_stylesheet_pack_tag for the usage guide"

        expect {
          javascript_pack_tag("application_with_integrity")
          append_javascript_pack_tag("bootstrap_with_integrity", defer: false)
        }.to raise_error(expected_error_message)
      end

      it "#prepend_javascript_pack_tag raises an error if called after calling #javascript_pack_tag" do
        expected_error_message = \
          "You can only call prepend_javascript_pack_tag before javascript_pack_tag helper. " +
          "Please refer to https://github.com/shakacode/shakapacker/blob/main/README.md#view-helper-append_javascript_pack_tag-prepend_javascript_pack_tag-and-append_stylesheet_pack_tag for the usage guide"

        expect {
          javascript_pack_tag("application_with_integrity")
          prepend_javascript_pack_tag("bootstrap_with_integrity", defer: false)
        }.to raise_error(expected_error_message)
      end

      it "#javascript_pack_tag generates the correct tags when passing `defer: true`" do
        expected = <<~HTML.chomp
            <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
            <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
            <script src="/packs/application-k344a6d59eef8632c9d1.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
        HTML

        expect_script_tags_match(javascript_pack_tag("application_with_integrity", defer: true), expected)
      end

      it "#javascript_pack_tag generates the correct tags when passing a symbol" do
        expected = <<~HTML.chomp
            <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
            <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
            <script src="/packs/application-k344a6d59eef8632c9d1.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
        HTML

        expect_script_tags_match(javascript_pack_tag(:application_with_integrity), expected)
      end

      it "#javascript_pack_tag raises error on multiple invocations" do
        expected_error_message = "To prevent duplicated chunks on the page, you should call javascript_pack_tag only once on the page. " +
                                 "Please refer to https://github.com/shakacode/shakapacker/blob/main/README.md#view-helpers-javascript_pack_tag-and-stylesheet_pack_tag for the usage guide"

        expect {
          javascript_pack_tag(:application_with_integrity)
          javascript_pack_tag(:bootstrap_with_integrity)
        }.to raise_error(expected_error_message)
      end

      it "#javascript_pack_tag generates the correct tags when passing `async: true`" do
        expected = <<~HTML.chomp
            <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js" crossorigin="anonymous" async="async" integrity="sha384-hash"></script>
            <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js" crossorigin="anonymous" async="async" integrity="sha384-hash"></script>
            <script src="/packs/application-k344a6d59eef8632c9d1.js" crossorigin="anonymous" async="async" integrity="sha384-hash"></script>
        HTML

        expect_script_tags_match(javascript_pack_tag("application_with_integrity", async: true), expected)
      end

      it "#javascript_pack_tag generates the correct tags when passing both `defer: true` and `async: true`" do
        # When both async and defer are specified, async takes precedence per HTML5 spec
        expected = <<~HTML.chomp
          <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js" crossorigin="anonymous" async="async" integrity="sha384-hash"></script>
          <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js" crossorigin="anonymous" async="async" integrity="sha384-hash"></script>
          <script src="/packs/application-k344a6d59eef8632c9d1.js" crossorigin="anonymous" async="async" integrity="sha384-hash"></script>
        HTML

        expect_script_tags_match(javascript_pack_tag("application_with_integrity", defer: true, async: true), expected)
      end

      it "#append_javascript_pack_tag supports the async attribute" do
        append_javascript_pack_tag("bootstrap_with_integrity", async: true)

        expected = <<~HTML.chomp
          <script src="/packs/bootstrap-300631c4f0e0f9c865bc.js" crossorigin="anonymous" async="async" integrity="sha384-hash"></script>
          <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
          <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
          <script src="/packs/application-k344a6d59eef8632c9d1.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
        HTML

        expect_script_tags_match(javascript_pack_tag("application_with_integrity"), expected)
      end

      it "#prepend_javascript_pack_tag supports the async attribute" do
        prepend_javascript_pack_tag("main_with_integrity", async: true)

        expected = <<~HTML.chomp
          <script src="/packs/main-e323a53c7f30f5d53cbb.js" crossorigin="anonymous" async="async" integrity="sha384-hash"></script>
          <script src="/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
          <script src="/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
          <script src="/packs/application-k344a6d59eef8632c9d1.js" crossorigin="anonymous" defer="defer" integrity="sha384-hash"></script>
        HTML

        expect_script_tags_match(javascript_pack_tag("application_with_integrity"), expected)
      end

      it "#stylesheet_pack_tag generates the correct link tag with string arguments" do
        expected = (application_stylesheet_chunks + hello_stimulus_stylesheet_chunks)
                     .uniq
                     .map { |chunk| stylesheet_link_tag(chunk, crossorigin: "anonymous", integrity: "sha384-hash") }
                     .join("\n")

        expect_stylesheet_link_tags_match(stylesheet_pack_tag("application_with_integrity", "hello_stimulus_with_integrity"), expected)
      end

      it "#stylesheet_pack_tag generates the correct link tag with symbol arguments" do
        expected = (application_stylesheet_chunks + hello_stimulus_stylesheet_chunks)
                     .uniq
                     .map { |chunk| stylesheet_link_tag(chunk, crossorigin: "anonymous", integrity: "sha384-hash") }
                     .join("\n")

        expect_stylesheet_link_tags_match(stylesheet_pack_tag(:application_with_integrity, :hello_stimulus_with_integrity), expected)
      end

      it "#stylesheet_pack_tag generates the correct link tag with mixed arguments" do
        expected = (application_stylesheet_chunks)
                     .map { |chunk| stylesheet_link_tag(chunk, media: "all", crossorigin: "anonymous", integrity: "sha384-hash") }
                     .join("\n")

        expect_stylesheet_link_tags_match(stylesheet_pack_tag("application_with_integrity", media: "all"), expected)
      end

      it "#stylesheet_pack_tag allows multiple invocations" do
        app_style = stylesheet_pack_tag(:application_with_integrity)
        stimulus_style = stylesheet_pack_tag(:hello_stimulus_with_integrity)

        expect_stylesheet_link_tags_match(app_style, application_stylesheet_chunks.map { |chunk| stylesheet_link_tag(chunk, crossorigin: "anonymous", integrity: "sha384-hash") }.join("\n"))

        expect_stylesheet_link_tags_match(stimulus_style, hello_stimulus_stylesheet_chunks.map { |chunk| stylesheet_link_tag(chunk, crossorigin: "anonymous", integrity: "sha384-hash") }.join("\n"))

        expect {
          stylesheet_pack_tag(:application_with_integrity)
          stylesheet_pack_tag(:hello_stimulus_with_integrity)
        }.to_not raise_error
      end

      it "#stylesheet_pack_tag appends tags" do
        append_stylesheet_pack_tag(:hello_stimulus_with_integrity)

        expect_stylesheet_link_tags_match(stylesheet_pack_tag("application_with_integrity"),
                                          (application_stylesheet_chunks + hello_stimulus_stylesheet_chunks).uniq.map { |chunk| stylesheet_link_tag(chunk, crossorigin: "anonymous", integrity: "sha384-hash") }.join("\n"))
      end

      it "#stylesheet_pack_tag appends duplicate" do
        append_stylesheet_pack_tag("hello_stimulus_with_integrity")
        append_stylesheet_pack_tag(:application_with_integrity)

        expect_stylesheet_link_tags_match(stylesheet_pack_tag("application_with_integrity"),
                                                       (application_stylesheet_chunks + hello_stimulus_stylesheet_chunks).uniq.map { |chunk| stylesheet_link_tag(chunk, crossorigin: "anonymous", integrity: "sha384-hash") }.join("\n"))
      end

      it "#stylesheet_pack_tag supports multiple invocations with different media attr values" do
        app_style = stylesheet_pack_tag(:application_with_integrity)
        app_style_with_media = stylesheet_pack_tag(:application_with_integrity, media: "print")
        hello_stimulus_style_with_media = stylesheet_pack_tag(:hello_stimulus_with_integrity, media: "all")

        expect_stylesheet_link_tags_match(app_style, application_stylesheet_chunks.map { |chunk| stylesheet_link_tag(chunk, crossorigin: "anonymous", integrity: "sha384-hash") }.join("\n"))
        expect_stylesheet_link_tags_match(app_style_with_media, application_stylesheet_chunks.map { |chunk| stylesheet_link_tag(chunk, media: "print", crossorigin: "anonymous", integrity: "sha384-hash") }.join("\n"))
        expect_stylesheet_link_tags_match(hello_stimulus_style_with_media, hello_stimulus_stylesheet_chunks.map { |chunk| stylesheet_link_tag(chunk, media: "all", crossorigin: "anonymous", integrity: "sha384-hash") }.join("\n"))
      end

      describe "#send_pack_early_hints with integrity hashes" do
        it "returns nil to avoid rendering output" do
          allow(Shakapacker.config).to receive(:early_hints).and_return({ enabled: true, include_css: true, include_js: true })
          expect(send_pack_early_hints("application_with_integrity")).to be_nil
        end

        it "does not call send_early_hints when early hints are disabled" do
          allow(Shakapacker.config).to receive(:early_hints).and_return({ enabled: false, include_css: true, include_js: true })
          expect(@request).not_to receive(:send_early_hints)
          send_pack_early_hints("application_with_integrity")
        end

        it "sends early hints with integrity hashes when enabled" do
          allow(Shakapacker.config).to receive(:early_hints).and_return({ enabled: true, include_css: true, include_js: true })
          expect(@request).to receive(:send_early_hints) do |headers|
            expect(headers).to have_key("Link")
            link_headers = headers["Link"]
            # Verify that integrity hashes are included in the Link headers
            expect(link_headers).to include("integrity=")
            expect(link_headers).to match(%r{</packs/vendors~application~bootstrap-c20632e7baf2c81200d3\.chunk\.js>})
            expect(link_headers).to match(%r{</packs/application-k344a6d59eef8632c9d1\.js>})
          end
          send_pack_early_hints("application_with_integrity")
        end

        it "sends early hints only for JavaScript when CSS is disabled" do
          allow(Shakapacker.config).to receive(:early_hints).and_return({ enabled: true, include_css: false, include_js: true })
          expect(@request).to receive(:send_early_hints) do |headers|
            expect(headers).to have_key("Link")
            link_headers = headers["Link"]
            expect(link_headers).to match(%r{</packs/vendors~application~bootstrap-c20632e7baf2c81200d3\.chunk\.js>})
            expect(link_headers).to include("as=script")
          end
          send_pack_early_hints("application_with_integrity")
        end

        it "allows per-call options to override config" do
          allow(Shakapacker.config).to receive(:early_hints).and_return({ enabled: true, include_css: false, include_js: true })
          expect(@request).to receive(:send_early_hints) do |headers|
            expect(headers).to have_key("Link")
            link_headers = headers["Link"]
            expect(link_headers).to match(%r{</packs/1-c20632e7baf2c81200d3\.chunk\.css>})
          end
          send_pack_early_hints("application_with_integrity", include_css: true)
        end

        it "gracefully handles missing entries" do
          allow(Shakapacker.config).to receive(:early_hints).and_return({ enabled: true, include_css: true, include_js: true })
          expect(@request).not_to receive(:send_early_hints)
          send_pack_early_hints("nonexistent_pack")
        end
      end

    end
  end
end
