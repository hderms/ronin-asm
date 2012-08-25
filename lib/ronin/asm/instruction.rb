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

require 'ronin/asm/literal'
require 'ronin/asm/immediate'

module Ronin
  module ASM
    class Instruction < Struct.new(:name, :operands)

      def initialize(name,operands)
        operands = operands.map do |op|
          case op
          when Integer, nil then Literal.new(op)
          else                   op
          end
        end

        super(name,operands)
      end

      def width
        self.operands.map { |op|
          op.width if op.respond_to?(:width)
        }.compact.max
      end

    end
  end
end
