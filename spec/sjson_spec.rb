# frozen_string_literal: true

RSpec.describe Sjson do
  it "has a version number" do
    expect(Sjson::VERSION).not_to be nil
  end

  it "parses 'false'" do
    expect(subject.feed_all("false")).to eq "false"
  end

  it "parses 'true'" do
    expect(subject.feed_all("true")).to eq "true"
  end

  it "parses 'null'" do
    expect(subject.feed_all("null")).to eq "null"
  end

  it "parses a number" do
    subject.feed_all("27")
    expect(subject.send(:data_from, subject.send(:state).last)).to eq "27"
  end

  it "parses a string" do
    expect(subject.feed_all('"test"')).to eq '"test"'
  end

  %w[[] [[]] [1] [true] [false] [null] ["hello"]].each do |v|
    it "parses #{v}" do
      expect(subject.feed_all(v)).to eq v
    end
  end

  ["{}", '{"test":true}', '{"test":[{"true":true,"array":[{"string":false}]}]}'].each do |v|
    it "parses #{v}" do
      expect(subject.feed_all(v)).to eq v
    end
  end

  it "fails with a borked object" do
    expect { subject.feed_all('{"a":"a" 123}') }
      .to raise_error(Sjson::ParseError).with_message("unexpected `1' at position 7")
  end

  it "fails with a borked number" do
    expect { subject.feed_all("123]") }
      .to raise_error(Sjson::ParseError).with_message(/unexpected character '\]'/)
  end

  it "parses an heterogeneous array" do
    val = "[null,1,\"1\",{}]"
    expect(subject.feed_all(val)).to eq val
  end

  it "parses array with newline" do
    expect(subject.feed_all("[1\n]")).to eq "[1]"
  end

  it "fails on 1eE2" do
    expect { subject.feed_all("1eE2") }
      .to raise_error(Sjson::ParseError).with_message("unexpected 'E', expected a number at position 1")
  end

  it "does not touch returned data after reset" do
    data = subject.feed_all("[]")
    expect(data).to eq "[]"
    subject.reset
    expect(data).to eq "[]"
    data = subject.feed_all("[]")
    expect(data).to eq "[]"
  end

  Dir["spec/fixtures/*.json"].each do |file|
    file_name = Pathname.new(file)
    expectation = {
      "y" => "parses",
      "n" => "fails",
      "i" => "is indifferent to"
    }[file_name.basename.to_s[0]]

    it "#{expectation} #{file_name.basename}" do
      if expectation == "fails"
        expect { subject.feed_all(File.read(file)) }
          .to raise_error(Sjson::ParseError)
      else
        expect { subject.feed_all(File.read(file)) }
          .not_to raise_error
      end
    end
  end
end
