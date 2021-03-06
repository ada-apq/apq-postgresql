------------------------------------------------------------------------------
--                                                                          --
--                          APQ DATABASE BINDINGS                           --
--                                                                          --
--                            A P Q - POSTGRESQL  			    --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--         Copyright (C) 2002-2007, Warren W. Gay VE3WWG                    --
--         Copyright (C) 2007-2011, KOW Framework Project                   --
--                                                                          --
--                                                                          --
-- APQ is free software;  you can  redistribute it  and/or modify it under  --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 2,  or (at your option) any later ver- --
-- sion.  APQ is distributed in the hope that it will be useful, but WITH-  --
-- OUT ANY WARRANTY;  without even the  implied warranty of MERCHANTABILITY --
-- or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License --
-- for  more details.  You should have  received  a copy of the GNU General --
-- Public License  distributed with APQ;  see file COPYING.  If not, write  --
-- to  the Free Software Foundation,  59 Temple Place - Suite 330,  Boston, --
-- MA 02111-1307, USA.                                                      --
--                                                                          --
-- As a special exception,  if other files  instantiate  generics from this --
-- unit, or you link  this unit with other files  to produce an executable, --
-- this  unit  does not  by itself cause  the resulting  executable  to  be --
-- covered  by the  GNU  General  Public  License.  This exception does not --
-- however invalidate  any other reasons why  the executable file  might be --
-- covered by the  GNU Public License.                                      --
------------------------------------------------------------------------------

with Ada.Exceptions;
with Ada.Calendar;
with Ada.Unchecked_Deallocation;
with Ada.Unchecked_Conversion;
with Ada.Characters.Latin_1;
with Ada.Characters.Handling;
with Ada.Strings.Fixed;
with ada.strings.maps;
with Ada.IO_Exceptions;
with System;
with System.Address_To_Access_Conversions;
with Interfaces.C.Strings;
with GNAT.OS_Lib;

use Interfaces.C;
use Ada.Exceptions;

package body APQ.PostgreSQL.Client is

	Seek_Set : constant Interfaces.C.int := 0;
	Seek_Cur : constant Interfaces.C.int := 1;
	Seek_End : constant Interfaces.C.int := 2;
	No_Date : Ada.Calendar.Time;

	type PQ_Status_Type is (
		Connection_OK,
		Connection_Bad,
		Connection_Started,		-- Waiting for connection to be made.
		Connection_Made,		-- Connection OK; waiting to send.
		Connection_Awaiting_Response,	-- Waiting for a response
		Connection_Auth_OK,		-- Received authentication
                         Connection_Setenv,		-- Negotiating environment.
                         Connection_ssl_startup,
                         Connection_needed
	);

	for PQ_Status_Type use (
		0,	-- CONNECTION_OK
		1,	-- CONNECTION_BAD
		2,	-- CONNECTION_STARTED
		3,	-- CONNECTION_MADE
		4,	-- CONNECTION_AWAITING_RESPONSE
		5,	-- CONNECTION_AUTH_OK
                6,	-- CONNECTION_SETENV
                7,        -- Connection_ssl_startup
                8         -- Connection_needed

                        );
   pragma convention(C,PQ_Status_Type);


	------------------------------
	-- DATABASE CONNECTION :
	------------------------------


	function Engine_Of(C : Connection_Type) return Database_Type is
	begin
		return Engine_PostgreSQL;
	end Engine_Of;



	function New_Query(C : Connection_Type) return Root_Query_Type'Class is
		Q : Query_Type;
	begin
		return Q;
	end New_Query;



	procedure Notify_on_Standard_Error(C : in out Connection_Type; Message : String) is
		use Ada.Text_IO;
	begin
		Put(Standard_Error,"*** NOTICE : ");
		Put_Line(Standard_Error,Message);
	end Notify_on_Standard_Error;



	procedure Set_Instance(C : in out Connection_Type; Instance : String) is
	begin
		Raise_Exception(Not_Supported'Identity,
			"PG01: PostgreSQL has no Instance ID. (Set_Instance)");
	end Set_Instance;



	function Host_Name(C : Connection_Type) return String is
	begin
		if not Is_Connected(C) then
			return Host_Name(Root_Connection_Type(C));
		else
			declare
				use Interfaces.C.Strings;
				function PQhost(PGconn : PG_Conn) return chars_ptr;
				pragma Import(C,PQhost,"PQhost");

				The_Host : chars_ptr := PQhost(C.Connection);
			begin
				if The_Host = Null_Ptr then
					return "localhost";
				end if;
				return Value_Of(The_Host);
			end;
		end if;
	end Host_Name;



	function Port(C : Connection_Type) return Integer is
	begin
		if not Is_Connected(C) then
			return Port(Root_Connection_Type(C));
		else
			declare
				use Interfaces.C.Strings;
				function PQport(PGconn : PG_Conn) return chars_ptr;
				pragma Import(C,PQport,"PQport");

				The_Port : String := Value_Of(PQport(C.Connection));
			begin
				return Integer'Value(The_Port);
			exception
				when others =>
					Raise_Exception(Invalid_Format'Identity,
						"PG02: Invalid port number or is a UNIX socket reference (Port).");
			end;
		end if;

		return 0;
	end Port;



	function Port(C : Connection_Type) return String is
	begin
		if not Is_Connected(C) then
			return Port(Root_Connection_Type(C));
		else
			declare
				use Interfaces.C.Strings;
				function PQport(PGconn : PG_Conn) return chars_ptr;
				pragma Import(C,PQport,"PQport");
			begin
				return Value_Of(PQport(C.Connection));
			end;
		end if;

	end Port;



	function DB_Name(C : Connection_Type) return String is
	begin
		if not Is_Connected(C) then
			return To_Case(DB_Name(Root_Connection_Type(C)),C.SQL_Case);
		else
			declare
				use Interfaces.C.Strings;
				function PQdb(PGconn : PG_Conn) return chars_ptr;
				pragma Import(C,PQdb,"PQdb");
			begin
				return Value_Of(PQdb(C.Connection));
			end;
		end if;

	end DB_Name;



	function User(C : Connection_Type) return String is
	begin
		if not Is_Connected(C) then
			return User(Root_Connection_Type(C));
		else
			declare
				use Interfaces.C.Strings;
				function PQuser(PGconn : PG_Conn) return chars_ptr;
				pragma Import(C,PQuser,"PQuser");
			begin
				return Value_Of(PQuser(C.Connection));
			end;
		end if;
	end User;



	function Password(C : Connection_Type) return String is
	begin
		if not Is_Connected(C) then
			return Password(Root_Connection_Type(C));
		else
			declare
				use Interfaces.C.Strings;
				function PQpass(PGconn : PG_Conn) return chars_ptr;
				pragma Import(C,PQpass,"PQpass");
			begin
				return Value_Of(PQpass(C.Connection));
			end;
		end if;
	end Password;



   procedure Set_DB_Name(C : in out Connection_Type; DB_Name : String) is

      procedure Use_Database(C : in out Connection_Type; DB_Name : String) is
         Q : Query_Type;
      begin
         begin
            Prepare(Q,To_Case("USE " & DB_Name,C.SQL_Case));
            Execute(Q,C);
         exception
            when SQL_Error =>
               Raise_Exception(APQ.Use_Error'Identity,
                               "PG03: Unable to select database " & DB_Name & ". (Use_Database)");
         end;
      end Use_Database;

   begin
      if not Is_Connected(C) then
         -- Modify context to connect to this database when we connect
         Set_DB_Name(Root_Connection_Type(C),DB_Name);
      else
         -- Use this database now
         Use_Database(C,DB_Name);
         -- Update context info if no exception thrown above
         Set_DB_Name(Root_Connection_Type(C),DB_Name);
      end if;

      C.keyname_val_cache_uptodate := false;

   end Set_DB_Name;



   procedure Set_Options(C : in out Connection_Type; Options : String) is
   begin
      Replace_String(C.Options,Set_Options.Options);
      C.keyname_val_cache_uptodate := false;
   end Set_Options;



   function Options(C : Connection_Type) return String is
   begin
      if not Is_Connected(C) then
         if C.Options /= null then
            return C.Options.all;
         end if;
      else
         declare
            use Interfaces.C.Strings;
            function PQoptions(PGconn : PG_Conn) return chars_ptr;
            pragma Import(C,PQoptions,"PQoptions");
         begin
            return Value_Of(PQoptions(C.Connection));
         end;
      end if;
      return "";
   end Options;



	procedure Set_Notify_Proc(C : in out Connection_Type; Notify_Proc : Notify_Proc_Type) is
	begin
		C.Notify_Proc := Set_Notify_Proc.Notify_Proc;
	end Set_Notify_Proc;



	function Notify_Proc(C : Connection_Type) return Notify_Proc_Type is
	begin
		return C.Notify_Proc;
	end Notify_Proc;


	--------------------------------------------------
	-- Connection_Notify is called by notices.c as
	-- a callback from the libpq interface.
	--------------------------------------------------
--  	procedure Connection_Notify(C_Addr : System.Address; Msg_Ptr : Interfaces.C.Strings.chars_ptr);
--  	pragma Export(C,Connection_Notify,"Connection_Notify");


	procedure Connection_Notify(C_Addr : System.Address; Msg_Ptr : Interfaces.C.Strings.chars_ptr) is
		use Interfaces.C.Strings;
		package Addr is new System.Address_To_Access_Conversions(Connection_Type);

		function Strip_Prefix(S : String) return String is
			use Ada.Strings.Fixed, Ada.Strings;
		begin
			if S(S'First..S'First+6) = "NOTICE:" then
				return Trim(S(S'First+7..S'Last),Left);
			end if;
			return S;
		end Strip_Prefix;

		Abrt_Notice :	constant String := "current transaction is aborted, queries ignored until end of transaction block";
		Conn :		Addr.Object_Pointer := Addr.To_Pointer(C_Addr);
		Msg :		String := Strip_Prefix(Strip_NL(To_Ada_String(Msg_Ptr)));
	begin
		if Conn.Notice /= null then
			Free(Conn.Notice);		-- Free last notice
		end if;
		-- Store new notice
		Conn.Notice := new String(1..Msg'Length);
		Conn.Notice.all := Msg;

		if Conn.Notice.all = Abrt_Notice then
			Conn.Abort_State := True;
		end if;

		if Conn.Notify_Proc /= Null then
			Conn.Notify_Proc(Conn.all,Conn.Notice.all);
		end if;

	end Connection_Notify;



	function PQ_Status(C : Connection_Type) return PQ_Status_Type is
		function PQstatus(C : PG_Conn) return PQ_Status_Type;
		pragma Import(C,PQstatus,"PQstatus");
	begin
		if C.Connection = Null_Connection then
			return Connection_Bad;
		else
			return PQstatus(C.Connection);
		end if;
	end PQ_Status;

	procedure Disconnect(C : in out Connection_Type) is
		procedure Notice_Uninstall(C : PG_Conn);
		pragma Import(C,notice_uninstall,"notice_uninstall");
		procedure PQfinish(C : PG_Conn);
		pragma Import(C,PQfinish,"PQfinish");
	begin

		if not Is_Connected(C) then
			Raise_Exception(Not_Connected'Identity,
				"PG09: Not connected. (Disconnect)");
		end if;

		Notice_Uninstall(C.Connection);		-- Disconnect callback notices
		PQfinish(C.Connection);			-- Now release the connection
		C.Connection  := Null_Connection;
		C.Abort_State := False;			-- Clear abort state
		C.Notify_Proc := null;			-- De-register the notify procedure

		if C.Trace_Mode = Trace_APQ or else C.Trace_Mode = Trace_Full then
			Ada.Text_IO.Put_Line(C.Trace_Ada,"-- DISCONNECT");
		end if;

		Reset(C);

	end Disconnect;



	function Is_Connected(C : Connection_Type) return Boolean is
	begin
		return PQ_Status(C) = Connection_OK;
	end Is_Connected;



	procedure Internal_Reset(C : in out Connection_Type; In_Finalize : Boolean := False) is
	begin
		Free_Ptr(C.Error_Message);

		if C.Connection /= Null_Connection then
			declare
				Q : Query_Type;
			begin
				Clear_Abort_State(C);
				if C.Rollback_Finalize or In_Abort_State(C) then
					if C.Trace_On and then C.Trace_Filename /= null and then In_Finalize = True then
						Ada.Text_IO.Put_Line(C.Trace_Ada,"-- ROLLBACK ON FINALIZE");
					end if;
					Rollback_Work(Q,C);
				else
					if C.Trace_On and then C.Trace_Filename /= null and then In_Finalize = True then
						Ada.Text_IO.Put_Line(C.Trace_Ada,"-- COMMIT ON FINALIZE");
					end if;
					Commit_Work(Q,C);
				end if;
			exception
				when others =>
					null;		-- Ignore if the Rollback/commit fails
			end;

			Clear_Abort_State(C);

			Disconnect(C);

			if C.Trace_Filename /= null then
				Close_DB_Trace(C);
			end if;

		end if;

      if C.Connection = Null_Connection then
         Free_Ptr(C.Host_Name);
         Free_Ptr(C.Host_Address);
         Free_Ptr(C.DB_Name);
         Free_Ptr(C.User_Name);
         Free_Ptr(C.User_Password);
         Free_Ptr(C.Options);
         Free_Ptr(C.Error_Message);
         Free_Ptr(C.Notice);
         --
         clear_all_key_nameval(c);

      end if;
   end Internal_Reset;



	procedure Reset(C : in out Connection_Type) is
	begin
		Internal_Reset(C,In_Finalize => False);
	end Reset;



	function Error_Message(C : Connection_Type) return String is
		function PQerrorMessage(C : PG_Conn) return Interfaces.C.Strings.chars_ptr;
		pragma Import(C,PQerrorMessage,"PQerrorMessage");
	begin
		if C.Connection = Null_Connection then
			if C.Error_Message /= null then
				return C.Error_Message.all;
			else
				return "";
			end if;
		else
			return To_Ada_String(PQerrorMessage(C.Connection));
		end if;
	end Error_Message;



	function Notice_Message(C : Connection_Type) return String is
	begin
		if C.Notice /= null then
			return C.Notice.all;
		end if;
		return "";
   end Notice_Message;
   --
   --
   function "="( Left :root_option_record2; right : root_option_record2) return boolean
   is
      pragma Optimize(time);

      lkey_s : string :=
	ada.Strings.fixed.Trim( ada.Characters.Handling.To_Lower(
	  ada.Strings.Unbounded.To_String( left.key_u)) ,
	  ada.Strings.Both );
      rkey_s : string :=
	ada.Strings.fixed.Trim( ada.Characters.Handling.To_Lower(
	  ada.Strings.Unbounded.To_String( right.key_u)) ,
	  ada.Strings.Both );
   begin
      if lkey_s = rkey_s then
	 return true;
      end if;
      return false;
   end "=";

   function quote_string( qkv : string ) return String
   is
      use ada.Strings;
      use ada.Strings.Fixed;

      function PQescapeString(to, from : System.Address; length : size_t) return size_t;
      pragma Import(C,PQescapeString,"PQescapeString");
      src : string := trim ( qkv , both );
      C_Length : size_t := src'Length * 2 + 1;
      C_From   : char_array := To_C(src);
      C_To     : char_array(0..C_Length-1);
      R_Length : size_t := PQescapeString(C_To'Address,C_From'Address,C_Length);
      -- viva!!! :-)
   begin
      return To_Ada(C_To);
   end quote_string;
   ----

   function quote_string( qkv : string ) return ada.Strings.Unbounded.Unbounded_String
   is
   begin
      return ada.Strings.Unbounded.To_Unbounded_String(String'(quote_string(qkv)));
   end quote_string;
   --
   function cache_key_nameval_uptodate( C : Connection_Type) --
                                       return boolean
   is
   begin
      return c.keyname_val_cache_uptodate;
   end cache_key_nameval_uptodate;

   --
   procedure cache_key_nameval_create( C : in out Connection_Type; force : boolean := false)--
   is
      pragma optimize(time);
      use ada.strings.Unbounded;
      use ada.strings.Fixed;
      use ada.Strings;
      use Ada.Characters.Handling;

      use apq.postgresql.client.options_list2;
      --
      tmp_ub_cache : Unbounded_String := To_Unbounded_String(160); -- pre-allocate :-)
      tmp_eq : Unbounded_String := to_Unbounded_String(" = '");
      tmp_ap : Unbounded_String := to_Unbounded_String("' ");
      --
      procedure process(position : cursor) is
	 val_tmp : root_option_record2 := element(position);
      begin
	 if val_tmp.is_valid = false then return; end if; --bahiii! :-)

	 tmp_ub_cache := tmp_ub_cache & val_tmp.key_u & tmp_eq &
	   trim(Unbounded_String'(quote_string(string'(To_String(val_tmp.value_u)))),ada.Strings.Both)
	   & tmp_ap ;

      end process;

   begin
      if cache_key_nameval_uptodate( C ) and force = false then return; end if; -- bahiii :-)
      c.keyname_val_cache := To_Unbounded_String("");

      if c.Port_Format = UNIX_Port then
         tmp_ub_cache := to_Unbounded_String("host")
           & tmp_eq & trim(Unbounded_String'(quote_string(string'(To_String(C.Host_Name)))),ada.Strings.both) & tmp_ap
           & to_Unbounded_String("port")
           & tmp_eq & trim(Unbounded_String'(quote_string(string'(To_String(C.Port_Name)))),ada.Strings.both) & tmp_ap ;
        elsif c.Port_Format = IP_Port then
         tmp_ub_cache := to_Unbounded_String("hostaddr")
           & tmp_eq & trim(Unbounded_String'(quote_string(string'(To_String(C.Host_Address)))),ada.Strings.both) & tmp_ap
           & to_Unbounded_String("port")
           & tmp_eq & trim(to_Unbounded_String(string'(Port_Integer'image(c.Port_Number))),ada.Strings.both) & tmp_ap;
      else
         raise program_error;
      end if;

      tmp_ub_cache := tmp_ub_cache
        & to_Unbounded_String("dbname") & tmp_eq & trim(Unbounded_String'(quote_string(string'(To_String(C.DB_Name)))),ada.Strings.both) & tmp_ap
        & to_Unbounded_String("user") & tmp_eq & trim(Unbounded_String'(quote_string(string'(To_String(C.User_Name)))),ada.Strings.both) & tmp_ap
        & to_Unbounded_String("password") & tmp_eq & trim(Unbounded_String'(quote_string(string'(To_String(C.User_Password)))),ada.Strings.both) & tmp_ap;
      if trim(string'(To_String(C.Options)), ada.Strings.Both) /= "" then
         tmp_ub_cache := tmp_ub_cache
         & to_Unbounded_String("options") & tmp_eq & trim(Unbounded_String'(quote_string(string'(To_String(C.Options)))), both) & tmp_ap ;
      end if;

      if not (c.key_name_list.Is_Empty ) then
	 c.key_name_list.Iterate(process'Access);
      end if;

      c.keyname_val_cache := tmp_ub_cache;

      tmp_ub_cache := To_Unbounded_String("");

   end cache_key_nameval_create;--
   --
   procedure clear_all_key_nameval(C : in out Connection_Type )
   is
      pragma optimize(time);
   begin
      if not ( c.key_name_list.is_empty ) then
	    c.key_name_list.clear;
      end if;
      c.keyname_val_cache := ada.Strings.Unbounded.To_Unbounded_String("");
      c.keyname_val_cache_uptodate := false;

   end clear_all_key_nameval;

   procedure key_nameval( L : in out options_list2.list ;
			 val : root_option_record2;
			 clear : boolean := false
			)
   is
      use options_list2;
      mi_cursor : options_list2.cursor := no_element;
   begin
      if clear then
	 if not ( L.is_empty ) then
	    L.clear;
	 end if;
      end if;
      if L.is_empty then
	 L.append(val);
	 return;
      end if;
      mi_cursor := L.find(val);
      if mi_cursor = No_Element then
	 L.append(val);
	 return;
      end if;
      L.replace_element(mi_cursor, val);

   end key_nameval;


   procedure add_key_nameval( C : in out Connection_Type;
                             kname, kval : string := "";
                             clear : boolean := false )
   is
      pragma optimize(time);
      use ada.strings;
      use ada.Strings.Fixed;

      tmp_kname : string  := string'(trim(kname,both));
      tmp_kval  : string  := string'(trim(kval,both));

   begin
      if tmp_kname = "" then return; end if; -- bahiii :-)
      declare
	 val_tmp : root_option_record2 :=
	   root_option_record2'(is_valid => true,
			 key_u    => ada.Strings.Unbounded.To_Unbounded_String(tmp_kname),
			 value_u  => ada.Strings.Unbounded.To_Unbounded_String(tmp_kval)
			);
      begin
	 key_nameval(L     => c.key_name_list,
	      val   => val_tmp ,
	      clear => clear);
      end;
      C.keyname_val_cache_uptodate := false;

   end add_key_nameval;

 --
   procedure clone_clone_pg(To : in out Connection_Type; From : Connection_Type )
   is
      pragma optimize(time);
      use apq.postgresql.client.options_list2;
      --
      procedure add(position : cursor) is
      begin
	 to.key_name_list.append(element(position));
      end add;

   begin
      clear_all_key_nameval(to);

      if not ( from.key_name_list.is_empty ) then
	    from.key_name_list.iterate(add'Access);
      end if;

      to.keyname_val_cache_uptodate := false;

   end clone_clone_pg;

   --
   procedure connect(C : in out Connection_Type; Check_Connection : Boolean := True)
   is
      pragma optimize(time);

      use Interfaces.C.Strings;

   begin
      if Check_Connection and then Is_Connected(C) then
         Raise_Exception(Already_Connected'Identity,
                         "PG07: Already connected (Connect).");
      end if;

      cache_key_nameval_create(C); -- don't worry :-) "re-create" accours only if not uptodate :-)
                                   -- This procedure can be executed manually if you desire :-)
                                   -- "for example": the "Connection_type" var was created  and configured
                                   -- much before the  connection with the DataBase server :-) take place
                                   -- then the "Connection_type" already uptodate
                                   -- ( well... uptodate if really uptodate ;-)
                                   -- this will speedy up the things a little :-)
      declare
         procedure Notice_Install(Conn : PG_Conn; ada_obj_ptr : System.Address);
         pragma import(C,Notice_Install,"notice_install");

         function PQconnectdb(coni : chars_ptr ) return PG_Conn;
         pragma import(C,PQconnectdb,"PQconnectdb");
         coni_str : string := ada.Strings.Unbounded.To_String(C.keyname_val_cache);
         C_conni : chars_ptr := New_String(Str => coni_str );
      begin
         C.Connection := PQconnectdb( C_conni); -- blocking call :-)
         Free_Ptr(C.Error_Message);

         if PQ_Status(C) /= Connection_OK then  -- if the connecting in a non-blocking fashion,
            -- there are more option of status needing verification :-)
            -- it Don't the case here
            declare
               procedure PQfinish(C : PG_Conn);
               pragma Import(C,PQfinish,"PQfinish");
               Msg : String := Strip_NL(Error_Message(C));
            begin
               PQfinish(C.Connection);
               C.Connection := Null_Connection;
               C.Error_Message := new String(1..Msg'Length);
               C.Error_Message.all := Msg;
               Raise_Exception(Not_Connected'Identity,
                               "PG08: Failed to connect to database server (Connect). error was: " &
                               msg ); -- more descriptive about 'what failed' :-)
            end;
         end if;

         Notice_Install(C.Connection,C'Address);	-- Install Connection_Notify handler

         ------------------------------
         -- SET PGDATESTYLE TO ISO;
         --
         -- This is necessary for all of the
         -- APQ date handling routines to
         -- function correctly. This implies
         -- that all APQ applications programs
         -- should use the ISO date format.
         ------------------------------
         declare
            SQL : Query_Type;
         begin
            Prepare(SQL,"SET DATESTYLE TO ISO");
            Execute(SQL,C);
         exception
            when Ex : others =>
               Disconnect(C);
               Reraise_Occurrence(Ex);
         end;
      end;

   end connect;

   procedure connect(C : in out Connection_Type; Same_As : Root_Connection_Type'Class)
   is
      pragma optimize(time);

      type Info_Func is access function(C : Connection_Type) return String;

      procedure Clone(S : in out String_Ptr; Get_Info : Info_Func) is
         Info : String := Get_Info(Connection_Type(Same_As));
      begin
         if Info'Length > 0 then
            S	:= new String(1..Info'Length);
            S.all	:= Info;
         else
            null;
            pragma assert(S = null);
         end if;
      end Clone;
      blo : boolean := true;
      tmpex : natural := 2;
   begin
      Reset(C);

      Clone(C.Host_Name,Host_Name'Access);

      C.Port_Format := Same_As.Port_Format;
      if C.Port_Format = IP_Port then
         C.Port_Number := Port(Same_As);	  -- IP_Port
      else
         Clone(C.Port_Name,Port'Access);	  -- UNIX_Port
      end if;

      Clone(C.DB_Name,DB_Name'Access);
      Clone(C.User_Name,User'Access);
      Clone(C.User_Password,Password'Access);
      Clone(C.Options,Options'Access);

      C.Rollback_Finalize	:= Same_As.Rollback_Finalize;
      C.Notify_Proc		:= Connection_Type(Same_As).Notify_Proc;
      -- I believe if "Same_As" var is defacto a "Connection_Type" as "C" var,
      -- there are need for copy  key's name and val from "Same_As" ,
      -- because in this keys and vals
      -- maybe are key's how sslmode , gsspi etc, that are defacto needs for connecting "C"

      if Same_As.Engine_Of = Engine_PostgreSQL then
         clone_clone_pg(C , Connection_Type(Same_as));
      end if;

     connect(C);	-- Connect to database before worrying about trace facilities

      -- TRACE FILE & TRACE SETTINGS ARE NOT CLONED

   end connect;

   function verifica_conninfo_cache( C : Connection_Type) return string -- for debug purpose :-P
                                                                        -- in the spirit there are an get_password(c) yet...

   is
   begin
      return ada.Strings.Unbounded.To_String(c.keyname_val_cache);
   end verifica_conninfo_cache;




	procedure Open_DB_Trace(C : in out Connection_Type; Filename : String; Mode : Trace_Mode_Type := Trace_APQ) is
	begin
		if C.Trace_Filename /= null then
			Raise_Exception(Tracing_State'Identity,
				"PG04: Already in a tracing state (Open_DB_Trace).");
		end if;

		if not Is_Connected(C) then
			Raise_Exception(Not_Connected'Identity,
				"PG05: Not connected (Open_DB_Trace).");
		end if;

		if Mode = Trace_None then
			pragma assert(C.Trace_Mode = Trace_None);
			return;	  -- No trace required
		end if;

		declare
			use CStr, System, Ada.Text_IO, Ada.Text_IO.C_Streams;
			procedure PQtrace(PGconn : PG_Conn; debug_port : CStr.FILEs);
			pragma Import(C,PQtrace,"PQtrace");

			C_Filename :	char_array := To_C(Filename);
			File_Mode :	char_array := To_C("a");
		begin
			C.Trace_File := fopen(C_Filename'Address,File_Mode'Address);
			if C.Trace_File = Null_Stream then
				Raise_Exception(Ada.IO_Exceptions.Name_Error'Identity,
					"PG06: Unable to open trace file " & Filename & " (Open_DB_Trace).");
			end if;

			Open(C.Trace_Ada,Append_File,C.Trace_File,Form => "shared=yes");
			Ada.Text_IO.Put_Line(C.Trace_Ada,"-- Start of Trace, Mode = " & Trace_Mode_Type'Image(Mode));

			if Mode = Trace_DB or Mode = Trace_Full then
				PQtrace(C.Connection,C.Trace_File);
			end if;

		end;

		C.Trace_Filename	:= new String(1..Filename'Length);
		C.Trace_Filename.all	:= Filename;
		C.Trace_Mode		:= Mode;
		C.Trace_On		:= True;		-- Enabled by default until Set_Trace disables this

	end Open_DB_Trace;



	procedure Close_DB_Trace(C : in out Connection_Type) is
	begin

		if C.Trace_Mode = Trace_None then
			return;		-- No tracing in progress
		end if;

		pragma assert(C.Trace_Filename /= null);

		declare
			use CStr;
			procedure PQuntrace(PGconn : PG_Conn);
			pragma Import(C,PQuntrace,"PQuntrace");
		begin
			if C.Trace_Mode = Trace_DB or C.Trace_Mode = Trace_Full then
				PQuntrace(C.Connection);
			end if;

			Free(C.Trace_Filename);

			Ada.Text_IO.Put_Line(C.Trace_Ada,"-- End of Trace.");
			Ada.Text_IO.Close(C.Trace_Ada);	-- This closes C.Trace_File too

			C.Trace_Mode	:= Trace_None;
			C.Trace_On	:= True;		-- Restore default
		end;

	end Close_DB_Trace;



	procedure Set_Trace(C : in out Connection_Type; Trace_On : Boolean := True) is
		procedure PQtrace(PGconn : PG_Conn; debug_port : CStr.FILEs);
		procedure PQuntrace(PGconn : PG_Conn);
		pragma Import(C,PQtrace,"PQtrace");
		pragma Import(C,PQuntrace,"PQuntrace");

		Orig_Trace : Boolean := C.Trace_On;
	begin
		C.Trace_On := Set_Trace.Trace_On;

		if Orig_Trace = C.Trace_On then
			return;		-- No change
		end if;

		if C.Trace_On then
			if C.Trace_Mode = Trace_DB or C.Trace_Mode = Trace_Full then
				PQtrace(C.Connection,C.Trace_File);		-- Enable libpq tracing
			end if;
		else
			if C.Trace_Mode = Trace_DB or C.Trace_Mode = Trace_Full then
				PQuntrace(C.Connection);			-- Disable libpq tracing
			end if;
		end if;
	end Set_Trace;



	function Is_Trace(C : Connection_Type) return Boolean is
	begin
		return C.Trace_On;
	end Is_Trace;



	function In_Abort_State(C : Connection_Type) return Boolean is
	begin
		if C.Connection = Null_Connection then
			return False;
		end if;
		return C.Abort_State;
	end In_Abort_State;



	------------------------------
	-- SQL QUERY API :
	------------------------------


	procedure Free(R : in out PQ_Result) is
		procedure PQclear(R : PQ_Result);
		pragma Import(C,PQclear,"PQclear");
	begin
		if R /= Null_Result then
			PQclear(R);
			R := Null_Result;
		end if;
	end Free;



	procedure Clear(Q : in out Query_Type) is
	begin
		Free(Q.Result);
		Clear(Root_Query_Type(Q));
	end Clear;



	procedure Append_Quoted(Q : in out Query_Type; Connection : Root_Connection_Type'Class; SQL : String; After : String := "") is
		function PQescapeString(to, from : System.Address; length : size_t) return size_t;
		pragma Import(C,PQescapeString,"PQescapeString");
		C_Length :	size_t := SQL'Length * 2 + 1;
		C_From :	char_array := To_C(SQL);
		C_To :		char_array(0..C_Length-1);
		R_Length :	size_t := PQescapeString(C_To'Address,C_From'Address,C_Length);
	begin
		Append(Q,"'" & To_Ada(C_To) & "'",After);
		Q.Caseless(Q.Count) := False; -- Preserve case for this one
	end Append_Quoted;



	procedure Execute(Query : in out Query_Type; Connection : in out Root_Connection_Type'Class) is
		function PQexec(C : PG_Conn; Q : System.Address) return PQ_Result;
		pragma Import(C,PQexec,"PQexec");
		R : Result_Type;
	begin

		Query.SQL_Case := Connection.SQL_Case;

		if not Is_Connected(Connection) then
			Raise_Exception(Not_Connected'Identity,
				"PG14: The Connection_Type object supplied is not connected (Execute).");
		end if;

		if In_Abort_State(Connection) then
			Raise_Exception(Abort_State'Identity,
				"PG15: The PostgreSQL connection is in the Abort state (Execute).");
		end if;

		if Query.Result /= Null_Result then
			Free(Query.Result);
		end if;

		declare
			A_Query :	String := To_String(Query);
			C_Query :	char_array := To_C(A_Query);
		begin
			if Connection.Trace_On then
				if Connection.Trace_Mode = Trace_APQ or Connection.Trace_Mode = Trace_Full then
					Ada.Text_IO.Put_Line(Connection.Trace_Ada,"-- SQL QUERY:");
					Ada.Text_IO.Put_Line(Connection.Trace_Ada,A_Query);
					Ada.Text_IO.Put_Line(Connection.Trace_Ada,";");
				end if;
			end if;

			Query.Result := PQexec(Internal_Connection(Connection_Type(Connection)),C_Query'Address);

			if Connection.Trace_On then
				if Connection.Trace_Mode = Trace_APQ or Connection.Trace_Mode = Trace_Full then
					Ada.Text_IO.Put_Line(Connection.Trace_Ada,"-- Result: '" & Command_Status(Query) & "'");
					Ada.Text_IO.New_Line(Connection.Trace_Ada);
				end if;
			end if;
		end;

		if Query.Result /= Null_Result then
			Query.Tuple_Index := First_Tuple_Index;
			R := Result(Query);
			if R /= Command_OK and R /= Tuples_OK then
--				if Connection.Trace_On then
--					Ada.Text_IO.Put_Line(Connection.Trace_Ada,"-- Error " &
--						Result_Type'Image(Query.Error_Code) & " : " & Error_Message(Query));
--				end if;
				Raise_Exception(SQL_Error'Identity,
					"PG16: The query failed (Execute).");
			end if;
		else
--			if Connection.Trace_On then
--				Ada.Text_IO.Put_Line(Connection.Trace_Ada,"-- Error " &
--					Result_Type'Image(Query.Error_Code) & " : " & Error_Message(Query));
--			end if;
			Raise_Exception(SQL_Error'Identity,
				"PG17: The query failed (Execute).");
		end if;

	end Execute;



	procedure Execute_Checked(Query : in out Query_Type; Connection : in out Root_Connection_Type'Class; Msg : String := "") is
		use Ada.Text_IO;
	begin
		begin
			Execute(Query,Connection);
		exception
			when Ex : SQL_Error =>
				if Msg'Length > 0 then
					Put(Standard_Error,"*** SQL ERROR: ");
					Put_Line(Standard_Error,Msg);
				else
					Put(Standard_Error,"*** SQL ERROR IN QUERY:");
					New_Line(Standard_Error);
					Put(Standard_Error,To_String(Query));
					if Col(Standard_Error) > 1 then
						New_Line(Standard_Error);
					end if;
				end if;
				Put(Standard_Error,"[");
				Put(Standard_Error,Result_Type'Image(Result(Query)));
				Put(Standard_Error,": ");
				Put(Standard_Error,Error_Message(Query));
				Put_Line(Standard_Error,"]");
				Reraise_Occurrence(Ex);
			when Ex : others =>
				Reraise_Occurrence(Ex);
		end;
	end Execute_Checked;



	procedure Begin_Work(Query : in out Query_Type; Connection : in out Root_Connection_Type'Class) is
	begin
		if In_Abort_State(Connection) then
			Raise_Exception(Abort_State'Identity,
				"PG36: PostgreSQL connection is in the abort state (Begin_Work).");
		end if;
		Clear(Query);
		Prepare(Query,"BEGIN WORK");
		Execute(Query,Connection);
		Clear(Query);
	end Begin_Work;



	procedure Commit_Work(Query : in out Query_Type; Connection : in out Root_Connection_Type'Class) is
	begin
		if In_Abort_State(Connection) then
			Raise_Exception(Abort_State'Identity,
				"PG37: PostgreSQL connection is in the abort state (Commit_Work).");
		end if;
		Clear(Query);
		Prepare(Query,"COMMIT WORK");
		Execute(Query,Connection);
		Clear(Query);
	end Commit_Work;



	procedure Rollback_Work(Query : in out Query_Type; Connection : in out Root_Connection_Type'Class) is
	begin
		Clear(Query);
		Prepare(Query,"ROLLBACK WORK");
		Execute(Query,Connection);
		Clear_Abort_State(Connection);
		Clear(Query);
	end Rollback_Work;



	procedure Rewind(Q : in out Query_Type) is
	begin
		Q.Rewound := True;
		Q.Tuple_Index := First_Tuple_Index;
	end Rewind;



	procedure Fetch(Q : in out Query_Type) is
	begin
		if not Q.Rewound then
			Q.Tuple_Index := Q.Tuple_Index + 1;
		else
			Q.Rewound := False;
		end if;
		Fetch(Q,Q.Tuple_Index);
	end Fetch;



	procedure Fetch(Q : in out Query_Type; TX : Tuple_Index_Type) is
		NT : Tuple_Count_Type := Tuples(Q); -- May raise No_Result
	begin
		if NT < 1 then
			Raise_Exception(No_Tuple'Identity,
				"PG33: There is no row" & Tuple_Index_Type'Image(TX) & " (Fetch).");
		end if;
		Q.Tuple_Index := TX;
		Q.Rewound := False;
		if TX > NT then
			Raise_Exception(No_Tuple'Identity,
				"PG34: There is no row" & Tuple_Index_Type'Image(TX) & " (Fetch).");
		end if;
	end Fetch;



	function End_of_Query(Q : Query_Type) return Boolean is
		NT : Tuple_Count_Type := Tuples(Q); -- May raise No_Result
	begin
		if NT < 1 then
			return True;		-- There are no tuples to return
		end if;

		if Q.Rewound then
			return False;		-- There is at least 1 tuple to return yet
		end if;

		return Tuple_Count_Type(Q.Tuple_Index) >= NT;	-- We've fetched them all
	end End_of_Query;



	function Tuple(Q : Query_Type) return Tuple_Index_Type is
		NT : Tuple_Count_Type := Tuples(Q); -- May raise No_Result
	begin
		if NT < 1 or else Q.Rewound then
			Raise_Exception(No_Tuple'Identity,
				"PG35: There are no tuples to return (Tuple).");
		end if;
		return Q.Tuple_Index;
	end Tuple;



	function Tuples(Q : Query_Type) return Tuple_Count_Type is
		use Interfaces.C;
		function PQntuples(R : PQ_Result) return int;
		pragma Import(C,PQntuples,"PQntuples");
	begin
		if Q.Result = Null_Result then
			Raise_Exception(No_Result'Identity,
				"PG19: There are no query results (Tuples).");
		end if;
		return Tuple_Count_Type(PQntuples(Q.Result));
	end Tuples;



	function Columns(Q : Query_Type) return Natural is
		use Interfaces.C;
		function PQnfields(R : PQ_Result) return int;
		pragma Import(C,PQnfields,"PQnfields");
	begin
		if Q.Result = Null_Result then
			Raise_Exception(No_Result'Identity,
				"PG20: There are no query results (Columns).");
		end if;
		return Natural(PQnfields(Q.Result));
	end Columns;



	function Column_Name(Q : Query_Type; CX : Column_Index_Type) return String is
		use Interfaces.C.Strings;
		function PQfname(R : PQ_Result; CBX : int) return chars_ptr;
		pragma Import(C,PQfname,"PQfname");

		CBX : int := int(CX) - 1;	  -- Make zero based
	begin
		if Q.Result = Null_Result then
			Raise_Exception(No_Result'Identity,
				"PG21: There are no query results (Column_Name).");
		end if;
		declare
			use Interfaces.C.Strings;
			CP : chars_ptr := PQfname(Q.Result,CBX);
		begin
			if CP = Null_Ptr then
				Raise_Exception(No_Column'Identity,
					"PG22: There is no column CX=" & Column_Index_Type'Image(CX) & ".");
			end if;
			return To_Case(Value_Of(CP),Q.SQL_Case);
		end;
	end Column_Name;



	function Column_Index(Q : Query_Type; Name : String) return Column_Index_Type is
		use Interfaces.C.Strings;
		function PQfnumber(R : PQ_Result; CBX : System.Address) return int;
		pragma Import(C,PQfnumber,"PQfnumber");

		C_Name :	char_array := To_C(Name);
		CBX :		int := -1;
	begin
		if Q.Result = Null_Result then
			Raise_Exception(No_Result'Identity,
				"PG23: There are no query results (Column_Index).");
		end if;
		CBX := PQfnumber(Q.Result,C_Name'Address);
		if CBX < 0 then
			Raise_Exception(No_Column'Identity,
				"PG24: There is no column named '" & Name & " (Column_Index).");
		end if;
		return Column_Index_Type(CBX+1);
	end Column_Index;



	function Is_Column(Q : Query_Type; CX : Column_Index_Type) return Boolean is
	begin
		if Q.Result = Null_Result then
			return False;
		end if;
		return Natural(CX) <= Columns(Q);
	end Is_Column;



	function Column_Type(Q : Query_Type; CX : Column_Index_Type) return Row_ID_Type is
		function PQftype(R : PQ_Result; Field_Index : int) return PQOid_Type;
		pragma Import(C,PQftype,"PQftype");
		CBX : int := int(CX) - 1;
	begin
		if Q.Result = Null_Result then
			Raise_Exception(No_Result'Identity,
				"PG25: There are no query results (Column_Type).");
		end if;
		if not Is_Column(Q,CX) then
			Raise_Exception(No_Column'Identity,
				"PG26: There is no column CX=" & Column_Index_Type'Image(CX) & " (Column_Type).");
		end if;
		return Row_ID_Type(PQftype(Q.Result,CBX));
	end Column_Type;



	function Is_Null(Q : Query_Type; CX : Column_Index_Type) return Boolean is
		use Interfaces.C.Strings;
		function PQgetisnull(R : PQ_Result; tup_num, field_num : int) return int;
		pragma Import(C,PQgetisnull,"PQgetisnull");
		C_TX :	int := int(Q.Tuple_Index) - 1;		-- Make zero based tuple #
		C_CX :	int := int(CX) - 1;			-- Field index
	begin
		if Q.Result = Null_Result then
			Raise_Exception(No_Result'Identity,
				"PG31: There are no query results (Is_Null).");
		end if;
		if not Is_Column(Q,CX) then
			Raise_Exception(No_Column'Identity,
				"PG32: There is now column" & Column_Index_Type'Image(CX) & " (Is_Null).");
		end if;
		return PQgetisnull(Q.Result,C_TX,C_CX) /= 0;
	end Is_Null;



	function Value(Query : Query_Type; CX : Column_Index_Type) return String is
		use Interfaces.C.Strings;
		function PQgetvalue(R : PQ_Result; tup_num, field_num : int) return chars_ptr;
		pragma Import(C,PQgetvalue,"PQgetvalue");
		function PQgetisnull(R : PQ_Result; tup_num, field_num : int) return int;
		pragma Import(C,PQgetisnull,"PQgetisnull");
		C_TX :	int := int(Query.Tuple_Index) - 1;	-- Make zero based tuple #
		C_CX :	int := int(CX) - 1;			-- Field index
	begin
		if Query.Result = Null_Result then
			Raise_Exception(No_Result'Identity,
				"PG27: There are no query results (Value).");
		end if;
		if not Is_Column(Query,CX) then
			Raise_Exception(No_Column'Identity,
				"PG28: There is no column CX=" & Column_Index_Type'Image(CX) & " (Value).");
		end if;
		declare
			use Ada.Strings, Ada.Strings.Fixed;

			C_Val : chars_ptr := PQgetvalue(Query.Result,C_TX,C_CX);
		begin
			if C_Val = Null_Ptr then
				Raise_Exception(No_Tuple'Identity,
					"PG29: There is no row" & Tuple_Index_Type'Image(Query.Tuple_Index) & " (Value).");
			elsif PQgetisnull(Query.Result,C_TX,C_CX) /= 0 then
				Raise_Exception(Null_Value'Identity,
					"PG30: Value for column" & Column_Index_Type'Image(CX) & " is NULL (Value).");
			else
				return Trim(Value_Of(C_Val),Right);
			end if;
		end;

	end Value;



	function Result(Query : Query_Type) return Natural is
	begin
		return Result_Type'Pos(Result(Query));
	end Result;



	function Result(Query : Query_Type) return Result_Type is
		function PQresultStatus(R : PQ_Result) return Result_Type;
		pragma Import(C,PQresultStatus,"PQresultStatus");
	begin
		if Query.Result = Null_Result then
			Raise_Exception(No_Result'Identity,
				"PG13: There are no query results (function Result).");
		end if;
		return PQresultStatus(Query.Result);
	end Result;



	function Command_Oid(Query : Query_Type) return Row_ID_Type is
		function PQoidValue(R : PQ_Result) return PQOid_Type;
		pragma Import(C,PQoidValue,"PQoidValue");
	begin

		if Query.Result = Null_Result then
			Raise_Exception(No_Result'Identity,
				"PG12: There are no query results (Command_Oid).");
		end if;

		return Row_ID_Type(PQoidValue(Query.Result));
	end Command_Oid;



	function Null_Oid(Query : Query_Type) return Row_ID_Type is
	begin
		return APQ.PostgreSQL.Null_Row_ID;
	end Null_Oid;



	function Command_Status(Query : Query_Type) return String is
		use Interfaces.C.Strings;
		function PQcmdStatus(R : PQ_Result) return chars_ptr;
		pragma Import(C,PQcmdStatus,"PQcmdStatus");
	begin

		if Query.Result = Null_Result then
			Raise_Exception(No_Result'Identity,
				"PG11: There are no query results (Command_Status).");
		end if;

		declare
			use Interfaces.C.Strings;
			Msg_Ptr : chars_ptr := PQcmdStatus(Query.Result);
		begin
			if Msg_Ptr = Null_Ptr then
				return "";
			else
				return Strip_NL(Value_Of(Msg_Ptr));
			end if;
		end;
	end Command_Status;




	function Error_Message(Query : Query_Type) return String is
		use Interfaces.C.Strings;
		function PQresultErrorMessage(R : PQ_Result) return chars_ptr;
		pragma Import(C,PQresultErrorMessage,"PQresultErrorMessage");
	begin
		if Query.Result = Null_Result then
			Raise_Exception(No_Result'Identity,
				"PG10: There are no query results (Error_Message).");
		end if;

		declare
			use Interfaces.C.Strings;
			Msg_Ptr : chars_ptr := PQresultErrorMessage(Query.Result);
		begin
			if Msg_Ptr = Null_Ptr then
				return "";
			else
				return Strip_NL(Value_Of(Msg_Ptr));
			end if;
		end;
	end Error_Message;



	function Is_Duplicate_Key(Query : Query_Type) return Boolean is
		Msg : String := Error_Message(Query);
		Dup : constant String := "ERROR:  Cannot insert a duplicate key";
	begin
		if Msg'Length < Dup'Length then
			return False;
		end if;
		return Msg(Msg'First..Msg'First+Dup'Length-1) = Dup;
	end Is_Duplicate_Key;



	function Engine_Of(Q : Query_Type) return Database_Type is
	begin
		return Engine_PostgreSQL;
	end Engine_Of;


	--------------------------------------------------
	-- BLOB SUPPORT :
	--------------------------------------------------

	function lo_creat(conn : PG_Conn; Mode : Mode_Type) return PQOid_Type;
	pragma Import(C,lo_creat,"lo_creat");

	function lo_open(conn : PG_Conn; Oid : PQOid_Type; Mode : Mode_Type) return Blob_Fd;
	pragma Import(C,lo_open,"lo_open");

	function lo_close(conn : PG_Conn; fd : Blob_Fd) return int;
	pragma Import(C,lo_close,"lo_close");

	function lo_read(conn : PG_Conn; fd : Blob_Fd; buf : System.Address; len : size_t) return int;
	pragma Import(C,lo_read,"lo_read");

	function lo_write(conn : PG_Conn; fd : Blob_Fd; buf : System.Address; len : size_t) return int;
	pragma Import(C,lo_write,"lo_write");

	function lo_unlink(conn : PG_Conn; Oid : PQOid_Type) return int;
	pragma Import(C,lo_unlink,"lo_unlink");

	function lo_lseek(conn : PG_Conn; fd : Blob_Fd; offset, whence : int) return int;
	pragma Import(C,lo_lseek,"lo_lseek");

	procedure Free is new Ada.Unchecked_Deallocation(Blob_Object,Blob_Type);


	-- internal

	function Raw_Index(Blob : Blob_Type) return Str.Stream_Element_Offset is
		use Ada.Streams;
		Offset : int;
	begin
		loop  -- In loop form in case EINTR processing should be required someday
			Offset := lo_lseek(Blob.Conn.Connection,Blob.Fd,0,Seek_Cur);
			exit when Offset >= 0;
			Raise_Exception(Blob_Error'Identity,
				"PG38: Server blob error occurred.");
		end loop;

		return Stream_Element_Offset(Offset + 1);
	end Raw_Index;




	procedure Raw_Set_Index(Blob : Blob_Object; To : Str.Stream_Element_Offset) is
		Offset :	int := int(To) - 1;
		Z :		int;
	begin
		loop  -- In loop form in case EINTR processing should be required someday
			Z := lo_lseek(Blob.Conn.Connection,Blob.Fd,Offset,Seek_Set);
			exit when Z >= 0;
			Raise_Exception(Blob_Error'Identity,
				"PG39: Server blob error occurred.");
		end loop;
	end Raw_Set_Index;



	function Internal_Size(Blob : Blob_Type) return Str.Stream_Element_Offset is
		use Ada.Streams;
		Saved_Pos :	Stream_Element_Offset := Raw_Index(Blob);
		End_Offset :	int := lo_lseek(Blob.Conn.Connection,Blob.Fd,0,Seek_End);
	begin
		if End_Offset < 0 then
			Raise_Exception(Blob_Error'Identity,
				"PG40: Server blob error occurred.");
		end if;
		Raw_Set_Index(Blob.all,Saved_Pos);
		return Stream_Element_Offset(End_Offset);
	end Internal_Size;



	procedure Internal_Write(
		Stream:		in out	Blob_Object;
		Item:		in	Ada.Streams.Stream_Element_Array
	) is
		use Ada.Streams;
		Total :	size_t := 0;
		Len :	size_t;
		IX :	Stream_Element_Offset := Item'First;
		N :	int;
	begin
		while IX < Item'Last loop
			Len	:= size_t(Item'Last - IX + 1);
			N	:= lo_write(Stream.Conn.Connection,Stream.Fd,Item(IX)'Address,Len);
			if N < 0 then
				Raise_Exception(Blob_Error'Identity,
					"PG43: Server blob write error occurred.");
			elsif N > 0 then
				IX := IX + Stream_Element_Offset(N);

				Stream.Phy_Offset := Stream.Phy_Offset + Stream_Element_Offset(N);
				if Stream.Phy_Offset - 1 > Stream.The_Size then
					Stream.The_Size := Stream.Phy_Offset - 1;
				end if;
			end if;

			if N = 0 then
				Raise_Exception(Ada.IO_Exceptions.End_Error'Identity,
					"PG44: End_Error raised while server was writing blob.");
			end if;
		end loop;

	end Internal_Write;



	procedure Internal_Read(
		Stream:	in out	Blob_Object;
		Item:	out	Ada.Streams.Stream_Element_Array;
		Last:	out	Ada.Streams.Stream_Element_Offset
	) is
		use Ada.Streams;

		Len :	size_t := size_t(Item'Length);
		N :	int;
	begin

		loop  -- In loop form in case EINTR processing should be required someday
			N := lo_read(Stream.Conn.Connection,Stream.Fd,Item(Item'First)'Address,Len);
			exit when N >= 0;
			Raise_Exception(Blob_Error'Identity,
				"PG41: Server blob error occurred while reading the blob.");
		end loop;

		if N = 0 then
			Raise_Exception(Ada.IO_Exceptions.End_Error'Identity,
				"PG42: Reached the end of blob while reading.");
		end if;

		Last := Item'First + Stream_Element_Offset(N) - 1;
		Stream.Phy_Offset := Stream.Phy_Offset + Stream_Element_Offset(N);

	end Internal_Read;



	procedure Internal_Blob_Open(Blob : in out Blob_Type; Mode : Mode_Type; Buf_Size : Natural := Buf_Size_Default) is
		use Ada.Streams;
	begin
		Blob.Mode	:= Internal_Blob_Open.Mode;
		Blob.Fd		:= lo_open(Blob.Conn.Connection,PQOid_Type(Blob.Oid),Blob.Mode);
		if Blob.Fd = -1 then
			Free(Blob);
			Raise_Exception(Blob_Error'Identity,
				"PG45: Unable to open blob on server (OID=" & Row_ID_Type'Image(Blob.Oid) & ").");
		end if;
		if Buf_Size > 0 then
			Blob.Buffer	:= new Stream_Element_Array(1..Stream_Element_Offset(Buf_Size));
			Blob.Buf_Empty	:= True;
			Blob.Buf_Dirty	:= False;
			Blob.Buf_Offset	:= 0;
			Blob.Log_Offset	:= 1;
			Blob.Phy_Offset	:= 1;
			Blob.The_Size	:= Stream_Element_Offset(Internal_Size(Blob));
		else
			null;		-- unbuffered blob operations will be used
		end if;
	end Internal_Blob_Open;



	procedure Internal_Set_Index(Blob : in out Blob_Object; To : Str.Stream_Element_Offset) is
		use Ada.Streams;
	begin
		if Blob.Phy_Offset /= Stream_Element_Offset(To) then
			Raw_Set_Index(Blob,To);
			Blob.Phy_Offset := Stream_Element_Offset(To);
		end if;
	end Internal_Set_Index;



	-- end internal



	function Blob_Create(DB : access Connection_Type; Buf_Size : Natural := Buf_Size_Default) return Blob_Type is
		Blob : Blob_Type;
	begin
		Blob := new Blob_Object(DB);
		Blob.Oid := Row_ID_Type(lo_creat(Blob.Conn.Connection,Read_Write));
		if Blob.Oid = -1 then
			free(Blob);
			Raise_Exception(Blob_Error'Identity,
				"PG46: Unable to create blob on server.");
		end if;

		begin
			Internal_Blob_Open(Blob,Write,Buf_Size);
		exception
			when Ex : others =>
				Blob_Unlink(DB.all,Blob.Oid);	-- Release what will result in an unused blob!
				Reraise_Occurrence(Ex);		-- HINT: Internal_Blob_Open() FAILS IF IT IS NOT IN A TRANSACTION!
		end;

		return Blob;
	end Blob_Create;



	function Blob_Open(DB : access Connection_Type; Oid : Row_ID_Type; Mode : Mode_Type; Buf_Size : Natural := Buf_Size_Default) return Blob_Type is
		Blob : Blob_Type;
	begin
		Blob		:= new Blob_Object(DB);
		Blob.Oid	:= Blob_Open.Oid;
		Internal_Blob_Open(Blob,Mode,Buf_Size);
		return Blob;
	end Blob_Open;



	procedure Blob_Flush(Blob : in out Blob_Object) is
	begin
		if Blob.Buffer /= null then
			if ( not Blob.Buf_Empty ) and Blob.Buf_Dirty then
				Internal_Set_Index(Blob,Blob.Buf_Offset);
				Internal_Write(Blob,Blob.Buffer(1..Blob.Buf_Size));
			end if;
			Blob.Buf_Dirty := False;
		else
			null;				-- Ignore flush calls in the unbuffered case
		end if;
	end Blob_Flush;



	procedure Blob_Flush(Blob : Blob_Type) is
	begin
		Blob_Flush(Blob.all);
	end Blob_Flush;



	procedure Internal_Blob_Close(Blob : in out Blob_Object) is
		Z : int;
	begin
		if Blob.Buffer /= null then
			if Blob.Buf_Dirty then
				Blob_Flush(Blob);
			end if;
			Free(Blob.Buffer);
		end if;

		Z := lo_close(Blob.Conn.Connection,Blob.Fd);
		if Z /= 0 then
			Raise_Exception(Blob_Error'Identity,
				"PG47: Server error when closing blob.");
		end if;
		Blob.Fd := -1;
	end Internal_Blob_Close;



	procedure Blob_Close(Blob : in out Blob_Type) is
	begin
		Internal_Blob_Close(Blob.all);
		Free(Blob);
	end Blob_Close;



	procedure Blob_Set_Index(Blob : Blob_Type; To : Blob_Offset) is
		use Ada.Streams;
	begin
		if Blob.Buffer /= null then
			Blob.Log_Offset := Stream_Element_Offset(To);
		else
			Internal_Set_Index(Blob.all,Stream_Element_Offset(To));
		end if;
	end Blob_Set_Index;



	function Internal_Index(Blob : Blob_Type) return Str.Stream_Element_Offset is
	begin
		return Blob.Phy_Offset;
	end Internal_Index;



	function Blob_Index(Blob : Blob_Type) return Blob_Offset is
	begin
		if Blob.Buffer /= null then
			return Blob_Offset(Blob.Log_Offset);
		else
			return Blob_Offset(Internal_Index(Blob));
		end if;
	end Blob_Index;



	function End_of_Blob(Blob : Blob_Type) return Boolean is
		use Ada.Streams;
	begin
		if Blob.Buffer /= null then
			return Blob.Log_Offset > Blob.The_Size;
		else
			return Blob_Index(Blob) > Blob_Size(Blob);
		end if;
	end End_of_Blob;



	function Blob_Oid(Blob : Blob_Type) return Row_ID_Type is
	begin
		return Blob.Oid;
	end Blob_Oid;



	function Blob_Size(Blob : Blob_Type) return Blob_Count is
	begin
		if Blob.Buffer /= null then
			return Blob_Count(Blob.The_Size);
		else
			return Blob_Count(Internal_Size(Blob));
		end if;
	end Blob_Size;



	function Blob_Stream(Blob : Blob_Type) return Root_Stream_Access is
	begin
		if Blob = Null then
			Raise_Exception(Blob_Error'Identity,
				"PG49: No blob to create a stream from (Blob_Stream).");
		end if;
		return Root_Stream_Access(Blob);
	end Blob_Stream;



	procedure Blob_Unlink(DB : Connection_Type; Oid : Row_ID_Type) is
		Z : int;
	begin
		Z := lo_unlink(DB.Connection,PQOid_Type(Oid));
		if Z = -1 then
			Raise_Exception(Blob_Error'Identity,
				"PG50: Unable to unlink blob OID=" & Row_ID_Type'Image(Oid) & " (Blob_Unlink).");
		end if;
	end Blob_Unlink;



	function lo_import(conn : PG_Conn; filename : System.Address) return int;
	pragma Import(C,lo_import,"lo_import");

	function lo_export(conn : PG_Conn; Oid : PQOid_Type; filename : System.Address) return int;
	pragma Import(C,lo_export,"lo_export");


	procedure Blob_Import(DB : Connection_Type; Pathname : String; Oid : out Row_ID_Type) is
		use Interfaces.C;
		P : char_array := To_C(Pathname);
		Z : int;
	begin
		Oid := Row_ID_Type'Last;
		Z := lo_import(DB.Connection,P'Address);
		if Z <= -1 then
			Raise_Exception(Blob_Error'Identity,
				"PG51: Unable to import blob from " & Pathname & " (Blob_Import).");
		end if;
		Oid := Row_ID_Type(Z);
	end Blob_Import;



	procedure Blob_Export(DB : Connection_Type; Oid : Row_ID_Type; Pathname : String) is
		P : char_array := To_C(Pathname);
		Z : int;
	begin
		Z := lo_export(DB.Connection,PQOid_Type(Oid),P'Address);
		if Z <= -1 then
			Raise_Exception(Blob_Error'Identity,
				"PG52: Unable to export blob to " & Pathname & " (Blob_Export).");
		end if;
	end Blob_Export;



	function Generic_Blob_Open(DB : access Connection_Type; Oid : Oid_Type; Mode : Mode_Type; Buf_Size : Natural := Buf_Size_Default) return Blob_Type is
	begin
		return Blob_Open(DB,Row_ID_Type(Oid),Mode,Buf_Size);
	end Generic_Blob_Open;



	function Generic_Blob_Oid(Blob : Blob_Type) return Oid_Type is
	begin
		return Oid_Type(Blob_Oid(Blob));
	end Generic_Blob_Oid;



	procedure Generic_Blob_Unlink(DB : Connection_Type; Oid : Oid_Type) is
	begin
		Blob_Unlink(DB,Row_ID_Type(Oid));
	end Generic_Blob_Unlink;



	procedure Generic_Blob_Import(DB : Connection_Type; Pathname : String; Oid : out Oid_Type) is
		Local_Oid : Row_ID_Type;
	begin
		Blob_Import(DB,Pathname,Local_Oid);
		Oid := Oid_Type(Local_Oid);
	end Generic_Blob_Import;



	procedure Generic_Blob_Export(DB : Connection_Type; Oid : Oid_Type; Pathname : String) is
	begin
		Blob_Export(DB,Row_ID_Type(Oid),Pathname);
	end Generic_Blob_Export;



-- private


	---------------------
	-- CONNECTION_TYPE --
	---------------------


   procedure Initialize(C : in out Connection_Type) is
   begin
      C.Port_Format := IP_Port;
      C.Port_Number := 5432;
      C.keyname_val_cache_uptodate := false;

   end Initialize;



	procedure Finalize(C : in out Connection_Type) is
	begin
		Internal_Reset(C,In_Finalize => True);
	end Finalize;



	function Internal_Connection(C : Connection_Type) return PG_Conn is
	begin
		return C.Connection;
	end Internal_Connection;



	function Query_Factory( C: in Connection_Type ) return Root_Query_Type'Class is
		q: Query_Type;
	begin
		return q;
	end query_factory;



	----------------
	-- QUERY_TYPE --
	----------------


	procedure Adjust(Q : in out Query_Type) is
	begin
		Q.Result := Null_Result;
		Adjust(Root_Query_Type(Q));
	end Adjust;



	procedure Finalize(Q : in out Query_Type) is
	begin
		Clear(Q);
	end Finalize;



 	function SQL_Code(Query : Query_Type) return SQL_Code_Type is
	begin
		return 0;
	end SQL_Code;



	---------------
	-- BLOB_TYPE --
	---------------


	procedure Finalize(Blob : in out Blob_Object) is
	begin
		if Blob.Fd /= -1 then
			Internal_Blob_Close(Blob);
		end if;
	end Finalize;



	procedure Read(
		Stream:	in out	Blob_Object;
		Item:	out	Ada.Streams.Stream_Element_Array;
		Last:	out	Ada.Streams.Stream_Element_Offset
	) is
		use Ada.Streams;

		IX : Stream_Element_Offset := Item'First;
		BX : Stream_Element_Offset;
	begin

		if Stream.Buffer /= null then
			while IX <= Item'Last and Stream.Log_Offset <= Stream.The_Size loop

				if ( not Stream.Buf_Empty ) and then Stream.Buf_Dirty then	-- if not empty and is dirty
					if Stream.Log_Offset < Stream.Buf_Offset		-- if offset too low
					or else Stream.Log_Offset >= Stream.Buf_Offset + Stream.Buf_Size then	-- or offset too high
						Blob_Flush(Stream);
						Stream.Buf_Empty := True;
					end if;
				end if;

				if Stream.Buf_Empty then					-- If we have an empty buffer then..
					if Stream.Log_Offset > Stream.The_Size + 1 then
						Raise_Exception(Ada.IO_Exceptions.End_Error'Identity,
							"PG47: End reached while reading blob.");
					end if;

					Stream.Buf_Offset := Stream.Log_Offset;			-- Start with our convenient offset
					Stream.Buf_Size	:= Stream.Buffer.all'Length;		-- Try to read entire buffer in
					if Stream.Buf_Offset + Stream.Buf_Size - 1 > Stream.The_Size then
						Stream.Buf_Size := Stream.The_Size + 1 - Stream.Buf_Offset;  -- read somewhat less in
					end if;
					Internal_Set_Index(Stream,Stream.Buf_Offset);
					Internal_Read(Stream,Stream.Buffer(1..Stream.Buf_Size),Last);
					if Last /= Stream.Buf_Size then				-- Check that all was read
						Raise_Exception(Blob_Error'Identity,
							"PG48: Error while reading from blob.");
					end if;
					Stream.Buf_Empty := False;				-- Buffer is not empty
					pragma assert(Stream.Buf_Dirty = False);		-- Should not be dirty at this point
					BX := Stream.Buffer.all'First;				-- Start reading from buffer here
				else
					BX := Stream.Log_Offset - Stream.Buf_Offset + Stream.Buffer.all'First;
				end if;

				Item(IX)		:= Stream.Buffer.all(BX);		-- Read item byte
				IX			:= IX + 1;				-- Advance item index
				Stream.Log_Offset	:= Stream.Log_Offset + 1;		-- Advance logical offset
			end loop;
			Last := IX - 1;
		else
			Internal_Read(Stream,Item,Last);
		end if;
	end Read;



	procedure Write(
		Stream:	in out	Blob_Object;
		Item:	in	Ada.Streams.Stream_Element_Array
	) is
		use Ada.Streams;

		IX : Stream_Element_Offset := Item'First;
		BX : Stream_Element_Offset := -1;
	begin

		if Stream.Buffer /= null then
			while IX <= Item'Last loop
				if ( not Stream.Buf_Empty ) and then Stream.Buf_Dirty then			-- Buffer is not empty and is dirty
					if		Stream.Log_Offset <  Stream.Buf_Offset			-- if offset too low
					or else Stream.Log_Offset >  Stream.Buf_Offset + Stream.Buf_Size	-- or offset too high
					or else Stream.Buf_Size	>= Stream.Buffer.all'Length then		-- or buffer is full then..
						Blob_Flush(Stream);						-- Flush out dirty data
						Stream.Buf_Empty := True;					-- Now mark buffer as empty
					else
						BX := Stream.Log_Offset - Stream.Buf_Offset + Stream.Buffer.all'First;
					end if;
				else
					BX := Stream.Log_Offset - Stream.Buf_Offset + Stream.Buffer.all'First;
				end if;

				if Stream.Buf_Empty then					-- if buf was empty or was just made empty then..
					Stream.Buf_Offset	:= Stream.Log_Offset;		-- Set to our convenient offset
					Stream.Buf_Size		:= 0;				-- No data in this buffer yet
					Stream.Buf_Dirty	:= False;			-- Make sure it's not marked dirty yet
					BX			:= Stream.Buffer.all'First;	-- Point to start of buffer
				end if;

				Stream.Buffer.all(BX)	:= Item(IX);				-- Write the byte
				IX			:= IX + 1;				-- Advance Item Index
				Stream.Log_Offset	:= Stream.Log_Offset + 1;		-- Advance the logical blob offset
				Stream.Buf_Empty	:= False;				-- Buffer is no longer empty
				Stream.Buf_Dirty	:= True;				-- Buffer has been modified

				if BX > Stream.Buf_Size then					-- Did the buffer contents grow?
					Stream.Buf_Size	 := Stream.Buf_Size + 1;		-- Buffer size has grown
				end if;
			end loop;
		else
			Internal_Write(Stream,Item);
		end if;
	end Write;


begin

	declare
		use Ada.Calendar;
	begin
		No_Date := Time_Of(Year_Number'First,Month_Number'First,Day_Number'First);
	end;

end APQ.PostgreSQL.Client;

-- End $Source: /cvsroot/apq/apq/apq-postgresql-client.adb,v $
