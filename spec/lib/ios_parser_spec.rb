require_relative '../spec_helper'
require 'ios_parser'

describe IOSParser do
  describe '.parse' do
    context 'indented region' do
      let(:input) { <<-END }
policy-map mypolicy_in
 class myservice_service
  police 300000000 1000000 exceed-action policed-dscp-transmit
   set dscp cs1
 class other_service
  police 600000000 1000000 exceed-action policed-dscp-transmit
   set dscp cs2
   command_with_no_args
END

      let(:output) do
        {
          commands:
            [{ args: ['policy-map', 'mypolicy_in'],
               commands:
                 [{ args: ['class', 'myservice_service'],
                    commands: [{ args: ['police', 300_000_000, 1_000_000,
                                        'exceed-action',
                                        'policed-dscp-transmit'],
                                 commands: [{ args: ['set', 'dscp', 'cs1'],
                                              commands: [], pos: 114 }],
                                 pos: 50
                               }],
                    pos: 24
                  },

                  { args: ['class', 'other_service'],
                    commands: [{ args: ['police', 600_000_000, 1_000_000,
                                        'exceed-action',
                                        'policed-dscp-transmit'],
                                 commands: [{ args: ['set', 'dscp', 'cs2'],
                                              commands: [], pos: 214 },
                                            { args: ['command_with_no_args'],
                                              commands: [], pos: 230 }],
                                 pos: 150
                               }],
                    pos: 128
                  }],
               pos: 0
             }]
        }
      end

      subject { described_class.parse(input) }

      it('constructs the right AST') do
        should be_a IOSParser::IOS::Document
        expect(subject.to_hash).to eq output
      end
    end # context 'indented region'
  end # describe '.parse'
end # describe IOSParser
