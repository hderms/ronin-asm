#
# Ronin ASM - A Ruby DSL for crafting Assembly programs and Shellcode.
#
# Copyright (c) 2007-2012 Hal Brodigan (postmodern.mod3 at gmail.com)
#
# This file is part of Ronin ASM.
#
# Ronin is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ronin is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Ronin.  If not, see <http://www.gnu.org/licenses/>
#

require 'ronin/asm/archs'
require 'ronin/asm/os'
require 'ronin/asm/literal'
require 'ronin/asm/register'
require 'ronin/asm/instruction'
require 'ronin/asm/syntax'

require 'tempfile'
require 'yasm/program'

module Ronin
  module ASM
    class Program

      # Supported Assembly Syntaxs
      SYNTAX = {
        :att   => Syntax::ATT,
        :intel => Syntax::Intel
      }

      # The Assembly Parsers
      PARSERS = {
        :att   => :gas,
        :intel => :nasm
      }

      # The targeted architecture
      attr_reader :arch

      # The targeted Operating System
      attr_reader :os

      # The registers available to the program
      attr_reader :registers

      # The registers used by the program
      attr_reader :allocated_registers

      # The instructions of the program
      attr_reader :instructions

      #
      # Initializes a new Assembly Program.
      #
      # @param [Hash] options
      #   Additional options.
      #
      # @option options [String, Symbol] :arch (:x86)
      #   The Architecture to target.
      #
      # @option options [String, Symbol] :os
      #   The Operating System to target.
      #
      # @option options [Hash{Symbol => Object}] :define
      #   Constants to define in the program.
      #
      # @yield []
      #   The given block will be evaluated within the program.
      #
      # @example
      #   Program.new(:arch => :amd64) do
      #     push  rax
      #     push  rbx
      #
      #     mov   rsp,     rax
      #     mov   rax[8],  rbx
      #   end
      #
      def initialize(options={},&block)
        @arch = options.fetch(:arch,:x86).to_sym

        @registers = {}
        @general_registers = []
        @allocated_registers = []

        @instructions = []

        extend Archs.require_const(@arch)
        initialize_arch if respond_to?(:initialize_arch)

        if options.has_key?(:os)
          @os = options[:os].to_s

          extend OS.const_get(@os)
        end

        if options[:define]
          options[:define].each do |name,value|
            instance_variable_set("@#{name}",value)
          end
        end

        instance_eval(&block) if block
      end

      #
      # Accesses a register.
      #
      # @param [String, Symbol] name
      #   The name of the register.
      #
      # @return [Register]
      #   The register.
      #
      # @raise [ArgumentError]
      #   The register could not be found.
      #
      def reg(name)
        name = name.to_sym

        unless @registers.has_key?(name)
          raise(ArgumentError,"unknown register: #{name}")
        end

        unless @allocated_registers.include?(name)
          # mark the register as being used, when it was first accessed
          @allocated_registers << name
        end

        return @registers[name]
      end

      #
      # Adds a new instruction to the program.
      #
      # @param [String, Symbol] name
      #
      # @param [Array] operands
      #
      def instruction(name,*operands)
        @instructions << Instruction.new(name.to_sym,operands)
      end

      #
      # Creates a literal of size 1 (byte).
      #
      # @param [Integer] number
      #   The value of the literal.
      #
      # @return [Literal]
      #   The new literal value.
      #
      def byte(number)
        Literal.new(number,1)
      end

      #
      # Creates a literal of size 2 (bytes).
      #
      # @param [Integer] number
      #   The value of the literal.
      #
      # @return [Literal]
      #   The new literal value.
      #
      def word(number)
        Literal.new(number,2)
      end

      #
      # Creates a literal of size 4 (bytes).
      #
      # @param [Integer] number
      #   The value of the literal.
      #
      # @return [Literal]
      #   The new literal value.
      #
      def dword(number)
        Literal.new(number,4)
      end

      #
      # Creates a literal of size 8 (bytes).
      #
      # @param [Integer] number
      #   The value of the literal.
      #
      # @return [Literal]
      #   The new literal value.
      #
      def qword(number)
        Literal.new(number,8)
      end

      #
      # Adds a label to the program.
      #
      # @param [Symbol, String] name
      #   The name of the label.
      #
      # @yield []
      #   The given block will be evaluated after the label has been
      #   added.
      #
      def label(name)
        @instructions << name.to_sym

        yield if block_given?
      end

      #
      # Generic method for pushing onto the stack.
      #
      # @param [Register, Integer] value
      #   The value to push.
      #
      def stack_push(value)
      end

      #
      # Generic method for popping off the stack.
      #
      # @param [Symbol] name
      #   The name of the reigster.
      #
      def stack_pop(name)
      end

      #
      # Generic method for clearing a register.
      #
      # @param [Symbol] name
      #   The name of the reigster.
      #
      def reg_clear(name)
      end

      #
      # Generic method for setting a register.
      #
      # @param [Register, Immediate, Integer] value
      #   The new value for the register.
      #
      # @param [Symbol] name
      #   The name of the reigster.
      #
      def reg_set(value,name)
      end

      #
      # Generic method for saving a register.
      #
      # @param [Symbol] name
      #   The name of the reigster.
      #
      def reg_save(name)
      end

      #
      # Generic method for loading a register.
      #
      # @param [Symbol] name
      #   The name of the reigster.
      #
      def reg_load(name)
      end

      #
      # Defines a critical region, where the specified Registers
      # should be saved and then reloaded.
      #
      # @param [Array<Symbol>] regs
      #   The registers to save and reload.
      #
      # @yield []
      #   The given block will be evaluated after the registers
      #   have been saved.
      #
      def critical(*regs)
        regs.each { |name| reg_save(name) }

        yield if block_given?

        regs.reverse_each { |name| reg_load(name) }
      end

      #
      # Evaluates code within the Program.
      #
      # @yield []
      #   The code to evaluate.
      #
      def eval(&block)
        instance_eval(&block)
      end

      #
      # Converts the program to Assembly Source Code.
      #
      # @param [Symbol] syntax
      #   The syntax to compile the program to.
      #
      def to_asm(syntax=:att)
        SYNTAX[syntax].emit_program(self)
      end

      #
      # Assembles the program.
      #
      # @param [Hash] options
      #   Additional options.
      #
      # @option options [Symbol, String] :syntax (:att)
      #   The syntax to compile the program to.
      #
      # @option options [Symbol] :format (:bin)
      #   The format of the assembled executable. May be one of:
      #
      #   * `:dbg` - Trace of all info passed to object format module.
      #   * `:bin` - Flat format binary.
      #   * `:dosexe` - DOS .EXE format binary.
      #   * `:elf` - ELF.
      #   * `:elf32` - ELF (32-bit).
      #   * `:elf64` - ELF (64-bit).
      #   * `:coff` - COFF (DJGPP).
      #   * `:macho` - Mac OS X ABI Mach-O File Format.
      #   * `:macho32` - Mac OS X ABI Mach-O File Format (32-bit).
      #   * `:macho64` - Mac OS X ABI Mach-O File Format (64-bit).
      #   * `:rdf` - Relocatable Dynamic Object File Format (RDOFF) v2.0.
      #   * `:win32` - Win32.
      #   * `:win64` / `:x64` - Win64.
      #   * `:xdf` - Extended Dynamic Object.
      #
      # @return [String]
      #   The raw Object Code of the program.
      #
      def assemble(options={})
        syntax  = options.fetch(:syntax,:att)
        format  = options.fetch(:format,:bin)
        parser  = PARSERS[syntax]
        objcode = nil

        source= Tempfile.new('ronin-asm.S')
        source.write(to_asm(syntax))
        source.close

        Tempfile.open('ronin-asm.o') do |output|
          YASM::Program.assemble(
            :file          => source.path,
            :parser        => PARSERS[syntax],
            :target        => @arch,
            :output_format => format,
            :output        => output.path
          )

          objcode = output.read
        end

        return objcode
      end

      protected

      # undefine the syscall method, so method_missing handles it
      undef syscall

      #
      # Defines a register.
      #
      # @param [Symbol] name
      #   The name of the reigster.
      #
      # @param [Integer] width
      #   The width of the register (in bytes).
      #
      def define_register(name,width,general=false)
        name = name.to_sym

        @registers[name] = Register.new(name,width)
        @general_registers << name if general
      end

      #
      # Allows adding unknown instructions to the program.
      #
      # @param [Symbol] name
      #   The name of the instruction.
      #
      # @param [Array] arguments
      #   Additional operands.
      #
      def method_missing(name,*arguments,&block)
        if (block && arguments.empty?)
          label(name,&block)
        elsif block.nil?
          instruction(name,*arguments)
        else
          super(name,*arguments,&block)
        end
      end

    end
  end
end