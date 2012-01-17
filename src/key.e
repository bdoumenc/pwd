-- This file is part of pwdmgr.
--
-- pwdmgr is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, version 3 of the License.
--
-- pwdmgr is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with pwdmgr.  If not, see <http://www.gnu.org/licenses/>.
--
class KEY

create {ANY}
   make, new

feature {ANY}
   name: FIXED_STRING
   pass: FIXED_STRING

   is_deleted: BOOLEAN is
      do
         Result := del_count = add_count
      end

   is_valid: BOOLEAN

   set_pass (a_pass: STRING) is
      require
         is_valid
         a_pass /= Void
      do
         pass := a_pass.intern
         add_count := add_count + 1
      ensure
         pass = a_pass.intern
         not is_deleted
      end

   delete is
      require
         is_valid
      do
         del_count := add_count
      ensure
         is_deleted
      end

   encoded: ABSTRACT_STRING is
      do
         Result := encoder # name # &add_count # &del_count # pass
      end

feature {}
   make (a_line: STRING) is
      require
         a_line /= Void
      local
         dat: STRING
      do
         if decoder.match(a_line) then
            dat := once ""
            is_valid := True

            dat.clear_count
            decoder.append_named_group(a_line, dat, once "name")
            name := dat.intern

            dat.clear_count
            decoder.append_named_group(a_line, dat, once "add")
            add_count := dat.to_integer

            dat.clear_count
            decoder.append_named_group(a_line, dat, once "del")
            del_count := dat.to_integer

            dat.clear_count
            decoder.append_named_group(a_line, dat, once "pass")
            pass := dat.intern
         end
      end

   new (a_name, a_pass: STRING) is
      require
         a_name /= Void
         a_pass /= Void
      do
         name := a_name.intern
         pass := a_name.intern
         add_count := 1
         is_valid := True
      ensure
         is_valid
         not is_deleted
      end

   add_count: INTEGER
   del_count: INTEGER

   decoder: REGULAR_EXPRESSION is
      local
         builder: REGULAR_EXPRESSION_BUILDER
      once
         Result := builder.convert_python_pattern("^(?P<name>[^:]+):(?P<add>[0-9]+):(?P<del>[0-9]+):(?P<pass>.*)$")
      end

   encoder: FIXED_STRING is
      once
         Result := "#(1):#(2):#(3):#(4)".intern
      end

invariant
   is_valid implies name /= Void
   del_count <= add_count

end
