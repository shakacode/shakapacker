describe "Command" do
  before do
    allow(Shakapacker.logger).to receive(:info)
  end

  describe "#compile" do
    it "returns success status when stale" do
      expect(Shakapacker.compiler).to receive(:stale?).and_return(true)
      expect(Shakapacker.compiler).to receive(:run_webpack).and_return(true)

      expect(Shakapacker.commands.compile).to be true
    end

    it "returns success status when fresh" do
      expect(Shakapacker.compiler).to receive(:stale?).and_return(false)

      expect(Shakapacker.commands.compile).to be true
    end

    it "returns failure status when stale" do
      expect(Shakapacker.compiler).to receive(:stale?).and_return(true)
      expect(Shakapacker.compiler).to receive(:run_webpack).and_return(false)

      expect(Shakapacker.commands.compile).to be false
    end
  end

  describe "#clean" do
    let(:now) { Time.parse("2021-01-01 12:34:56 UTC") }
    let(:prev_files) do
      # Test assets to be kept and deleted, path and mtime
      {
        # recent versions to be kept with Shakapacker.commands.clean(count = 2)
        "js/application-deadbeef.js" => now - 4000,
        "js/common-deadbeee.js" => now - 4002,
        "css/common-deadbeed.css" => now - 4004,
        "media/images/logo-deadbeeb.css" => now - 4006,
        "js/application-1eadbeef.js" => now - 8000,
        "js/common-1eadbeee.js" => now - 8002,
        "css/common-1eadbeed.css" => now - 8004,
        "media/images/logo-1eadbeeb.css" => now - 8006,
        # new files to be kept with Shakapacker.commands.clean(age = 3600)
        "js/brandnew-0001.js" => now,
        "js/brandnew-0002.js" => now - 10,
        "js/brandnew-0003.js" => now - 20,
        "js/brandnew-0004.js" => now - 40,
      }.transform_keys { |path| "#{Shakapacker.config.public_output_path}/#{path}" }
    end

    let(:expired_files) do
      {
        # old files that are outside count = 2 or age = 3600 and to be deleted
        "js/application-0eadbeef.js" => now - 9000,
        "js/common-0eadbeee.js" => now - 9002,
        "css/common-0eadbeed.css" => now - 9004,
        "js/brandnew-0005.js" => now - 3640,
      }.transform_keys { |path| "#{Shakapacker.config.public_output_path}/#{path}" }
    end

    let(:all_files) { prev_files.merge(expired_files) }

    let(:file_delete_mock) { double("File Delete") }
    let(:file_mtime_stub) { Proc.new { |longpath| all_files[longpath] } }
    let(:file_delete_stub) { Proc.new { |longpath| file_delete_mock.delete(longpath) } }

    before :context do
      @dir_glob_stub = Proc.new { |arg|
        case arg
        when "#{Shakapacker.config.public_output_path}/**/*"
          all_files.keys
        else
          []
        end
      }
    end

    it "works with nested hashes and without any compiled files" do
      allow(File).to receive(:delete).and_return(true)
      expect(Shakapacker.commands.clean).to be true
    end

    it "deletes only and only expired versioned files if no parameter passed" do
      all_files.keys.each do |longpath|
        allow(file_delete_mock).to receive(:delete).with(longpath)
      end

      with_time_dir_and_files_stub do
        expect(Shakapacker.commands.clean).to be true

        # Verify that only and only expired files are deleted
        all_files.keys.each do |longpath|
          if expired_files.has_key? longpath
            expect(file_delete_mock).to have_received(:delete).with(longpath)
          else
            expect(file_delete_mock).to_not have_received(:delete).with(longpath)
          end
        end
      end
    end

    private

      def with_time_dir_and_files_stub(&proc)
        allow(Time).to receive(:now).and_return(now)
        allow(Dir).to receive(:glob) { |arg| @dir_glob_stub.call(arg) }
        allow(File).to receive(:directory?).and_return(false)
        allow(File).to receive(:file?).and_return(true)
        allow(File).to receive(:mtime) { |arg| file_mtime_stub.call(arg) }
        allow(File).to receive(:delete) { |arg| file_delete_stub.call(arg) }

        yield proc
      end
  end
end
