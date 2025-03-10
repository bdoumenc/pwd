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
expanded class SHARED

insert
   CONFIGURABLE
   LOGGING

feature {ANY}
   server_fifo: FIXED_STRING is
      once
         Result := eval(mandatory_key(config_server_fifo))
      end

   vault_file: FIXED_STRING is
      once
         Result := eval(mandatory_key(config_vault_file))
      end

   log_file (tag: ABSTRACT_STRING): FIXED_STRING is
      require
         tag /= Void
      do
         Result := eval(once "#(1)/#(2).log" # mandatory_key(config_log_dir) # tag)
      end

   tmp_dir: FIXED_STRING is
      once
         Result := eval(mandatory_key(config_tmp_fifo_dir))
      end

feature {}
   mandatory_key (key: FIXED_STRING): FIXED_STRING is
      require
         key /= Void
      do
         Result := conf(key)
         if Result = Void then
            std_error.put_line(once "Missing [shared]#(1)" # key)
            sedb_breakpoint
            die_with_code(1)
         end
      ensure
         Result /= Void
      end

   eval (string: ABSTRACT_STRING): FIXED_STRING is
      require
         string /= Void
      local
         processor: PROCESSOR
      do
         Result := processor.split_arguments(string).first.intern
      end

   config_server_fifo: FIXED_STRING is
      once
         Result := "server.fifo".intern
      end

   config_log_dir: FIXED_STRING is
      once
         Result := "log.dir".intern
      end

   config_vault_file: FIXED_STRING is
      once
         Result := "vault.file".intern
      end

   config_tmp_fifo_dir: FIXED_STRING is
      once
         Result := "tmp.fifo.dir".intern
      end

end
