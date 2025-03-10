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
class MENU

inherit
   CLIENT

create {}
   make

feature {}
   run is
      do
         send_menu
      end

   list: FAST_ARRAY[STRING]

   send_menu is
      require
         not fifo.exists(client_fifo)
      do
         call_server(once "list #(1)" # client_fifo,
                     agent (stream: INPUT_STREAM) is
                        do
                           from
                              create list.make(0)
                              stream.read_line
                           until
                              stream.end_of_input
                           loop
                              list.add_last(stream.last_string.twin)
                              stream.read_line
                           end
                           if not stream.last_string.is_empty then
                              list.add_last(stream.last_string.twin)
                           end
                        end)
         if list /= Void and then not list.is_empty then
            display_menu
         end
      end

   display_menu is
      require
         list /= Void
      local
         proc: PROCESS; proc_input: OUTPUT_STREAM; entry: STRING
      do
         proc := processor.execute_redirect(once "dmenu", conf(config_dmenu_arguments))
         if proc.is_connected then
            proc_input := proc.input
            list.do_all(agent display(?, proc_input))
            proc_input.disconnect
            proc.output.read_line
            if not proc.output.end_of_input then
               entry := proc.output.last_string.twin
            end
            proc.wait
            if proc.status = 0 and then entry /= Void and then not entry.is_empty then
               do_get(entry, agent xclip, agent is do end)
            end
         end
      end

   display (line: STRING; output: OUTPUT_STREAM) is
      require
         list /= Void
         output.is_connected
      do
         output.put_line(line)
      end

   config_dmenu_arguments: FIXED_STRING is
      once
         Result := "dmenu.arguments".intern
      end

   unknown_key (key: ABSTRACT_STRING) is
      do
         check False end
      end

end
