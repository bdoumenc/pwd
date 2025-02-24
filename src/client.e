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
deferred class CLIENT

insert
   GLOBALS
   FILE_TOOLS

feature {}
   processor: PROCESSOR

   tmpdir: FIXED_STRING
   client_fifo: FIXED_STRING
   restart: BOOLEAN

   preload is
      do
         inspect
            configuration.argument_count
         when 0 then
            -- OK
         when 1 then
            configuration.parse_extra_conf(configuration.argument(1))
         else
            std_error.put_line("Usage: #(1) [<fallback conf>]")
            die_with_code(1)
         end

         if configuration.filename = Void then
            std_error.put_line(once "Could not find any valid configuration file")
            die_with_code(1)
         end
      end

   main is
      do
         tmpdir := fifo.tmp
         if tmpdir = Void then
            log.error.put_line("#(1): could not create tmp directory!" # command_name)
            die_with_code(1)
         end

         client_fifo := ("#(1)/fifo" # tmpdir).intern

         from
            restart := True
         until
            not restart
         loop
            restart := False
            check_server
            run
         end

         cleanup
      rescue
         cleanup
         crash
      end

   cleanup is
      do
         if fifo.exists(client_fifo) then
            delete(client_fifo)
         end
         delete(client_fifo.substring(client_fifo.lower, client_fifo.upper - 5)) -- "/fifo".count
      end

   run is
      require
         not fifo.exists(client_fifo)
      deferred
      end

feature {}
   fifo: FIFO

   server_fifo: FIXED_STRING is
      do
         Result := shared.server_fifo
      end

   check_server is
      do
         if not file_exists(shared.vault_file) then
            check
               not fifo.exists(server_fifo)
            end
            log.info.put_line(once "Creating new vault: #(1)" # shared.vault_file)
            read_new_master(once "This is a new vault")
            create_vault
            start_server
            send_master
         elseif not fifo.exists(server_fifo) then
            log.info.put_line(once "Starting server using vault: #(1)" # shared.vault_file)
            start_server
            master_pass.copy(read_password(once "Please enter your encryption phrase%Nto open the password vault.", Void))
            send_master
         end
      end

   start_server is
      require
         not fifo.exists(server_fifo)
      local
         proc: PROCESS; arg: ABSTRACT_STRING
      do
         log.info.put_line(once "starting server...")
         if configuration.argument_count = 1 then
            arg := once "pwdsrv '#(1)'" # configuration.argument(1)
         else
            arg := once "pwdsrv"
         end
         proc := processor.execute_to_dev_null(once "nohup", arg)
         if proc.is_connected then
            proc.wait
            if proc.status = 0 then
               log.info.put_line(once "server started.")
            else
               log.error.put_line(once "server not started! (exit=#(1))" # proc.status.out)
               sedb_breakpoint
               die_with_code(proc.status)
            end
            fifo.wait_for(server_fifo)
            fifo.sleep(250)
         end
      ensure
         fifo.exists(server_fifo)
      end

   call_server (cmd: ABSTRACT_STRING; action: PROCEDURE[TUPLE[INPUT_STREAM]]) is
         -- communication with the server
      require
         fifo.exists(server_fifo)
         not fifo.exists(client_fifo)
      local
         tfr: TEXT_FILE_READ
      do
         fifo.make(client_fifo)
         send(cmd)
         fifo.wait_for(client_fifo)
         create tfr.connect_to(client_fifo)
         if tfr.is_connected then
            action.call([tfr])
            tfr.disconnect
            delete(client_fifo)
         end
      ensure
         not fifo.exists(client_fifo)
      end

feature {} -- get a password from the server
   data: RING_ARRAY[STRING] is
      once
         create Result.with_capacity(16, 0)
      end

   get_back (stream: INPUT_STREAM; key: ABSTRACT_STRING; callback: PROCEDURE[TUPLE[STRING]]; when_unknown: PROCEDURE[TUPLE[ABSTRACT_STRING]]) is
      require
         callback /= Void
         when_unknown /= Void
      do
         stream.read_line
         if not stream.end_of_input then
            data.clear_count
            stream.last_string.split_in(data)
            if data.count = 2 then
               callback.call([data.last])
            else
               check data.count = 1 end
               when_unknown.call([key])
            end
         end
      end

   do_get (key: ABSTRACT_STRING; callback: PROCEDURE[TUPLE[STRING]]; when_unknown: PROCEDURE[TUPLE[ABSTRACT_STRING]]) is
         -- get key
      require
         callback /= Void
         when_unknown /= Void
      do
         call_server(once "get #(1) #(2)" # client_fifo # key,
                     agent get_back(?, key, callback, when_unknown))
      end

   unknown_key (key: ABSTRACT_STRING) is
      deferred
      end

feature {REMOTE}
   get_password (key: ABSTRACT_STRING): STRING is
      local
         pass: REFERENCE[STRING]
      do
         create pass
         do_get(key,
                agent (p: STRING; p_ref: REFERENCE[STRING]) is
                   do
                      p_ref.set_item(p)
                   end (?, pass),
                agent unknown_key)
         Result := pass.item
      end

feature {} -- master phrase
   master_pass: STRING is ""

   read_password (text: ABSTRACT_STRING; on_cancel: PROCEDURE[TUPLE]): STRING is
      require
         text /= Void
      local
         proc: PROCESS
      do
         proc := processor.execute_redirect(once "zenity", zenity_args(text))
         if proc.is_connected then
            proc.output.read_line
            if not proc.output.end_of_input then
               Result := proc.output.last_string
            end
            proc.wait
            if proc.status /= 0 then
               if on_cancel /= Void then
                  on_cancel.call([])
                  Result := Void
               else
                  std_error.put_line(once "Cancelled.")
                  die_with_code(1)
               end
            end
         end
      end

   zenity_args (text: ABSTRACT_STRING): ABSTRACT_STRING is
      do
         Result := once "--entry --hide-text --title=Password --text=%"#(1)%"" # text
      end

   send_master is
      require
         fifo.exists(server_fifo)
      do
         send(once "master #(1)" # master_pass)
      end

   send_save is
      do
         send(once "save #(1)" # shared.vault_file)
      end

   send (string: ABSTRACT_STRING) is
      require
         fifo.exists(server_fifo)
         string /= Void
      local
         tfw: TEXT_FILE_WRITE
      do
         create tfw.connect_to(server_fifo)
         if tfw.is_connected then
            tfw.put_line(string)
            tfw.flush

            -- give time to the OS and the server to get the message before closing the connection
            fifo.sleep(100)

            tfw.disconnect
         end
      end

feature {} -- xclip
   xclip (string: ABSTRACT_STRING) is
      require
         string /= Void
      do
         xclipboards.do_all(agent xclip_select(string, ?))
      end

   xclip_select (string: ABSTRACT_STRING; selection: STRING) is
      local
         proc: PROCESS
      do
         proc := processor.execute(once "xclip", once "-selection #(1) -loops 3" # selection)
         if proc.is_connected then
            proc.input.put_line(string)
            proc.input.disconnect
            proc.wait
         end
      end

   xclipboards: FAST_ARRAY[STRING] is
      once
         Result := {FAST_ARRAY[STRING] << "primary", "clipboard" >>}
      end

feature {} -- create a brand new vault
   read_new_master (reason: ABSTRACT_STRING) is
      local
         pass1, pass2: STRING; text: ABSTRACT_STRING
      do
         from
            text := once "#(1),%Nplease enter an encryption phrase." # reason
         until
            pass1 /= Void
         loop
            pass1 := once ""
            pass1.copy(read_password(text, Void))
            text := once "Please enter the same encryption phrase again." # reason
            pass2 := read_password(text, Void)
            if not pass1.is_equal(pass2) then
               text := once "Your phrases did not match.%N#(1),%Nplease enter an encryption phrase." # reason
               pass1 := Void
            end
         end
         check
            by_construction: pass1.is_equal(pass2)
         end
         master_pass.copy(pass1)
      end

   create_vault is
      local
         new_vault: VAULT
      do
         create new_vault.make(shared.vault_file)
         new_vault.open_new(master_pass)
         new_vault.save(shared.vault_file.out)
         new_vault.close
      end

invariant
   server_fifo /= Void
   client_fifo /= Void

end
