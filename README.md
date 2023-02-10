# Sjson

Sjson handles JSON streams and ensures a complete JSON object has been read
before returning it to the caller, ensuring it is minimally sane for parsing.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add sjson

If bundler is not being used to manage dependencies, install the gem by
executing:

    $ gem install sjson

## Usage

Sjson takes characters from a stream, and returns the JSON string once the
structure is complete. For instance:

```ruby
require 'sjson'
require 'json'

handler = Sjson.new

data = StringIO.new(<<-JSON)
{ "name": "Paul Appleseed" }
JSON

read = data.readpartial(14) # Reads '{ "name": "Pau'
read.each_char do |chr|
    result = handler.feed(chr) # result is always nil.
end

read = data.readpartial(13) # Reads 'l Appleseed" '
read.each_char do |chr|
    result = handler.feed(chr) # result is always nil.
end

# Feeding the last character that completes the structure returns the structure
# data:

read = data.readpartial(1) # Reads '}'
result = handler.feed(read) # Feed the last read character
result
# => "{\"name\":\"Paul Appleseed\"}"

# Which can now be parsed
JSON.parse(result)
# => {"name"=>"Paul Appleseed"}
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then,
run `rake spec` to run the tests. You can also run `bin/console` for an
interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and the created tag, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/heyvito/sjson. This project is intended to be a safe,
welcoming space for collaboration, and contributors are expected to adhere
to the [code of conduct](https://github.com/heyvito/sjson/blob/master/CODE_OF_CONDUCT.md).

## Code of Conduct

Everyone interacting in the Sjson project's codebases, issue trackers, chat
rooms and mailing lists is expected to follow the
[code of conduct](https://github.com/heyvito/sjson/blob/master/CODE_OF_CONDUCT.md).

## License

```
The MIT License (MIT)

Copyright (c) 2023 Victor Gama

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

```
