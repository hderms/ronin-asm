require 'spec_helper'
require 'ronin/asm/shellcode'

describe ASM::Shellcode do
  describe "#assemble", :yasm => true do
    subject do
      described_class.new do
        xor   eax,  eax
        push  eax
        push  0x68732f2f
        push  0x6e69622f
        mov   esp,  ebx
        push  eax
        push  ebx
        mov   esp,  ecx
        xor   edx,  edx
        mov   0xb,  al
        int   0x80
      end
    end

    let(:shellcode) { "f1\xC0fPfh//shfh/binf\x89\xE3fPfSf\x89\xE1f1\xD2\xB0\v\xCD\x80" }

    it "assemble down to raw machine code" do
      subject.assemble.should == shellcode
    end

    context "with :syntax => :intel" do
      it "assemble down to raw machine code" do
        subject.assemble(:syntax => :intel).should == shellcode
      end
    end
  end
end
