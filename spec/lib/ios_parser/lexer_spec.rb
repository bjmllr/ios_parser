require_relative '../../spec_helper'
require 'ios_parser'
require 'ios_parser/lexer'

module IOSParser
  describe Lexer do
    describe '#call' do
      subject { klass.new.call(input) }

      let(:subject_pure) do
        IOSParser::PureLexer.new.call(input)
      end

      context 'indented region' do
        let(:input) { <<-END.unindent }
          policy-map mypolicy_in
           class myservice_service
            police 300000000 1000000 exceed-action policed-dscp-transmit
             set dscp cs1
           class other_service
            police 600000000 1000000 exceed-action policed-dscp-transmit
             set dscp cs2
END

        let(:output) do
          ['policy-map', 'mypolicy_in', :EOL,
           :INDENT,
           'class', 'myservice_service', :EOL,
           :INDENT,
           'police', 300_000_000, 1_000_000, 'exceed-action',
           'policed-dscp-transmit', :EOL,
           :INDENT,
           'set', 'dscp', 'cs1', :EOL,
           :DEDENT, :DEDENT,
           'class', 'other_service', :EOL,
           :INDENT,
           'police', 600_000_000, 1_000_000, 'exceed-action',
           'policed-dscp-transmit', :EOL,
           :INDENT,
           'set', 'dscp', 'cs2', :EOL, :DEDENT, :DEDENT, :DEDENT]
        end

        subject { klass.new.call(input).map(&:value) }
        it('enclosed in symbols') { should == output }

        it('enclosed in symbols (using the pure ruby lexer)') do
          expect(subject_pure.map(&:value)).to eq output
        end
      end

      context 'ASR indented regions' do
        context 'indented region' do
          let(:input) { <<-END.unindent }
            router static
             vrf MGMT
              address-family ipv4 unicast
               0.0.0.0/0 1.2.3.4
              !
             !
            !
            router ospf 12345
             nsr
END

          let(:expectation) do
            ['router', 'static', :EOL,
             :INDENT, 'vrf', 'MGMT', :EOL,
             :INDENT, 'address-family', 'ipv4', 'unicast', :EOL,
             :INDENT, '0.0.0.0/0', '1.2.3.4', :EOL,
             :DEDENT, :DEDENT, :DEDENT,
             'router', 'ospf', 12_345, :EOL,
             :INDENT, 'nsr', :EOL,
             :DEDENT]
          end

          it 'pure' do
            tokens = IOSParser::PureLexer.new.call(input)
            expect(tokens.map(&:value)).to eq expectation
          end # it 'pure' do

          it 'default' do
            tokens = IOSParser.lexer.new.call(input)
            expect(tokens.map(&:value)).to eq expectation
          end # it 'c' do
        end # context 'indented region' do
      end # context 'ASR indented regions' do

      context 'banners' do
        let(:input) do
          <<-END.unindent
            banner foobar ^
            asdf 1234 9786 asdf
            line 2
            line 3
              ^
END
        end

        let(:output) do
          [[0, 1, 1, 'banner'], [7, 1, 8, 'foobar'],
           [14, 1, 15, :BANNER_BEGIN],
           [16, 2, 17, "asdf 1234 9786 asdf\nline 2\nline 3\n  "],
           [52, 5, 3, :BANNER_END], [53, 5, 4, :EOL]]
            .map { |pos, line, col, val| Token.new(val, pos, line, col) }
        end

        it('tokenized and enclosed in symbols') { should == output }

        it('tokenized and enclodes in symbols (using the pure ruby lexer)') do
          expect(subject_pure).to eq output
        end
      end

      context 'complex banner' do
        let(:input) do
          text_fixture('complex_banner')
        end

        let(:output) do
          content = text_fixture('complex_banner').lines[1..-2].join
          ['banner', 'exec', :BANNER_BEGIN, content, :BANNER_END, :EOL]
        end

        it { expect(subject.map(&:value)).to eq output }
        it { expect(subject_pure.map(&:value)).to eq output }
      end

      context 'complex eos banner' do
        let(:input) { "banner motd\n'''\nEOF\n" }

        let(:output) do
          content = input.lines[1..-2].join
          ['banner', 'motd', :BANNER_BEGIN, content, :BANNER_END, :EOL]
        end

        it { expect(subject.map(&:value)).to eq output }
        it { expect(subject_pure.map(&:value)).to eq output }
      end

      context 'aaa authentication banner' do
        let(:input) { <<END.unindent }
        aaa authentication banner ^C
        xyz
        ^C
        aaa blah
END

        let(:output) do
          ['aaa', 'authentication', 'banner',
           :BANNER_BEGIN, "xyz\n", :BANNER_END, :EOL,
           'aaa', 'blah', :EOL]
        end

        it 'lexes (c lexer)' do
          expect(subject.map(&:value)).to eq output
        end

        it 'lexes (ruby lexer)' do
          expect(subject_pure.map(&:value)).to eq output
        end
      end

      context 'decimal number' do
        let(:input) { 'boson levels at 93.2' }
        let(:output) { ['boson', 'levels', 'at', 93.2] }
        subject { klass.new.call(input).map(&:value) }
        it('converts to Float') { should == output }
      end

      context 'cryptographic certificate' do
        let(:input) do
          <<END.unindent
            crypto pki certificate chain TP-self-signed-0123456789
             certificate self-signed 01
              FFFFFFFF FFFFFFFF FFFFFFFF FFFFFFFF FFFFFFFF FFFFFFFF FFFFFFFF FFFFFFFF
              EEEEEEEE EEEEEEEE EEEEEEEE EEEEEEEE EEEEEEEE EEEEEEEE EEEEEEEE EEEEEEEE
              DDDDDDDD DDDDDDDD DDDDDDDD DDDDDDDD DDDDDDDD DDDDDDDD DDDDDDDD DDDDDDDD AAAA
                    quit
            !
END
        end

        let(:output) do
          [[0, 1, 1, 'crypto'],
           [7, 1, 8, 'pki'],
           [11, 1, 12, 'certificate'],
           [23, 1, 24, 'chain'],
           [29, 1, 30, 'TP-self-signed-0123456789'],
           [54, 1, 55, :EOL],
           [56, 2, 2, :INDENT],
           [56, 2, 2, 'certificate'],
           [68, 2, 14, 'self-signed'],
           [80, 2, 26, '01'],
           [85, 3, 3, :CERTIFICATE_BEGIN],
           [85, 3, 3,
            'FFFFFFFF FFFFFFFF FFFFFFFF FFFFFFFF FFFFFFFF FFFFFFFF FFFFFFFF '\
            'FFFFFFFF EEEEEEEE EEEEEEEE EEEEEEEE EEEEEEEE EEEEEEEE EEEEEEEE '\
            'EEEEEEEE EEEEEEEE DDDDDDDD DDDDDDDD DDDDDDDD DDDDDDDD DDDDDDDD '\
            'DDDDDDDD DDDDDDDD DDDDDDDD AAAA'],
           [323, 6, 1, :CERTIFICATE_END],
           [323, 6, 13, :EOL],
           [323, 7, 1, :DEDENT]]
            .map { |pos, line, col, val| Token.new(val, pos, line, col) }
        end

        subject { klass.new.call(input) }

        it('tokenized') do
          expect(subject).to eq output
        end

        it('tokenized (using the pure ruby lexer)') do
          expect(subject_pure).to eq output
        end
      end

      context 'comments' do
        let(:input) { 'ip addr 127.0.0.0.1 ! asdfsdf' }
        let(:output) { ['ip', 'addr', '127.0.0.0.1', :EOL] }
        subject { klass.new.call(input).map(&:value) }
        it('dropped') { should == output }
      end

      context 'quoted octothorpe' do
        let(:input) { <<-EOS.unindent }
          vlan 1
           name "a #"
          vlan 2
           name d
      EOS

        let(:output) do
          [
            'vlan', 1, :EOL,
            :INDENT, 'name', '"a #"', :EOL,
            :DEDENT,
            'vlan', 2, :EOL,
            :INDENT, 'name', 'd', :EOL,
            :DEDENT
          ]
        end

        it { expect(subject_pure.map(&:value)).to eq output }
        it { expect(subject.map(&:value)).to eq output }
      end # context 'quoted octothorpe' do

      context 'vlan range' do
        let(:input) { 'switchport trunk allowed vlan 50-90' }
        let(:output) do
          [
            [0,  1, 1, 'switchport'],
            [11, 1, 12, 'trunk'],
            [17, 1, 18, 'allowed'],
            [25, 1, 26, 'vlan'],
            [30, 1, 31, '50-90']
          ].map { |pos, line, col, val| Token.new(val, pos, line, col) }
        end
        it { should == output }
      end # context 'vlan range' do

      context 'partial dedent' do
        let(:input) do
          <<END.unindent
            class-map match-any foobar
              description blahblahblah
             match access-group fred
END
        end

        let(:output) do
          [
            'class-map', 'match-any', 'foobar', :EOL,
            :INDENT, 'description', 'blahblahblah', :EOL,
            'match', 'access-group', 'fred', :EOL,
            :DEDENT
          ]
        end

        it { expect(subject_pure.map(&:value)).to eq output }
      end

      context '# in the middle of a line is not a comment' do
        let(:input) { "vlan 1\n name #31337" }
        let(:output) { ['vlan', 1, :EOL, :INDENT, 'name', '#31337', :DEDENT] }

        it { expect(subject_pure.map(&:value)).to eq output }
        it { expect(subject.map(&:value)).to eq output }
      end

      context '# at the start of a line is a comment' do
        let(:input) { "vlan 1\n# comment\nvlan 2" }
        let(:output) { ['vlan', 1, :EOL, 'vlan', 2] }

        it { expect(subject_pure.map(&:value)).to eq output }
        it { expect(subject.map(&:value)).to eq output }
      end

      context '# after indentation is a comment' do
        let(:input) { "vlan 1\n # comment\nvlan 2" }
        let(:output) { ['vlan', 1, :EOL, :INDENT, :DEDENT, 'vlan', 2] }

        it { expect(subject_pure.map(&:value)).to eq output }
        it { expect(subject.map(&:value)).to eq output }
      end

      context 'unterminated quoted string' do
        let(:input) { '"asdf' }
        it 'raises a lex error' do
          expect { subject_pure }.to raise_error IOSParser::LexError
          expect { subject }.to raise_error IOSParser::LexError

          pattern = /Unterminated quoted string starting at 0: #{input}/
          expect { subject_pure }.to raise_error(pattern)
          expect { subject }.to raise_error(pattern)
        end
      end

      context 'subcommands separated by comment line' do
        let(:input) do
          <<-END.unindent
            router static
             address-family ipv4 unicast
             !
             address-family ipv6 unicast
          END
        end

        let(:expected) do
          expected_full.map(&:value)
        end

        let(:expected_full) do
          [
            [0,  1, 1, 'router'],
            [7,  1, 8, 'static'],
            [13, 1, 14, :EOL],
            [15, 2, 2, :INDENT],
            [15, 2, 2, 'address-family'],
            [30, 2, 17, 'ipv4'],
            [35, 2, 22, 'unicast'],
            [42, 2, 29, :EOL],
            [47, 4, 2, 'address-family'],
            [62, 4, 17, 'ipv6'],
            [67, 4, 22, 'unicast'],
            [74, 4, 29, :EOL],
            [74, 4, 29, :DEDENT]
          ].map { |pos, line, col, val| Token.new(val, pos, line, col) }
        end

        it 'lexes both subcommands' do
          expect(subject.map(&:value)).to eq expected
        end

        it 'lexes both subcommands (with the pure ruby lexer)' do
          expect(subject_pure.map(&:value)).to eq expected
        end

        it 'lexes position, line, and column' do
          expect(subject).to eq expected_full
        end

        it 'lexes position, line, and column (with the pure ruby lexer)' do
          expect(subject_pure).to eq expected_full
        end
      end

      context 'comment at end of line' do
        let(:input) do
          <<-END.unindent
            description !
            switchport access vlan 2
          END
        end

        let(:output) do
          ['description', :EOL, 'switchport', 'access', 'vlan', 2, :EOL]
        end

        it { expect(subject_pure.map(&:value)).to eq output }
        it { expect(subject.map(&:value)).to eq output }
      end # context 'comment at end of line' do

      context 'large integers up to 2^63-1' do
        let(:input) do
          "42 4200000000 9223372036854775807"
        end

        let(:output) do
          [42, 4200000000, 9223372036854775807]
        end

        it { expect(subject_pure.map(&:value)).to eq output }
        it { expect(subject.map(&:value)).to eq output }
      end # context 'large integers up to 2^63-1' do
    end
  end
end
