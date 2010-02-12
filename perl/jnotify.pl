#
# Copyright (c) 2009 by Nils Görs <weechatter@arcor.de>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# v0.5: unhook notify_me() (by rettub)
#     : option for external command (by rettub)
#     : standard command is now only display beep (by rettub)
#     : external command does not freeze weechat anymore (by myself;-)
#     : using %N and %C for nick and channel-name
#     : added %S for internal server-name
#     : added whitelist and blacklist (suggested and code used from rettub)
#     : added "block_current_buffer" option
# v0.4: auto completion
# v0.3: $extern_command better readable and typo "toogle" instead of "toggle" removed
# v0.2: variable bug removed
# v0.1: first step (in perl)
#
# This script starts an external progam when a user JOIN a chat you are in.
# possible arguments you can give to the external program:
# %N : for the nick-name
# %C : for the channel-name
# %S : for the internal server-name
#
# /set plugins.var.perl.jnotify.blacklist = "jn-blacklist.txt"
# /set plugins.var.perl.jnotify.whitelist = "jn-whitelist.txt"
# /set plugins.var.perl.jnotify.block_current_buffer = "on"
# /set plugins.var.perl.jnotify.cmd = "echo -en "\a"" 
# /set plugins.var.perl.jnotify.status = "on"
#
#
# TODO: a buddy list in a seperate buffer
#
use strict;
#### Use your own external command here (do not forget the ";" at the end of line):
my $extern_command = qq(echo -en "\a");

# examples:
# playing a sound
# my $extern_command = qq(play -q $HOME/sounds/hello.wav);
# write to an output file.
# $extern_command = qq('echo "\"%C\" \"neuer User: %N\"">>/tmp/jnotify-`date +"%Y%m%d"`.log');
# this is my favorite. Displays weechat-logo + channel + nick using system-notification.
# my $extern_command = qq(notify-send -t 9000 -i $HOME/.weechat/120px-Weechat_logo.png "\"%C\" \"neuer User: %N\");

###########################
### program starts here ###
###########################
# default values in setup file (~/.weechat/plugins.conf)
my $version		= "0.5";
my $prgname 		= "jnotify";
my $description 	= "starts an external program if a user or one of your buddies JOIN a channel you are in";
my $status		= "status";
my $default_status	= "on";
my $block_current_buffer= "off";
my $whitelist		= "whitelist";
my $default_whitelist	= "jn-whitelist.txt";
my $blacklist		= "blacklist";
my $default_blacklist	= "jn-blacklist.txt";
my %Hooks               = ();

my %Allowed = ();
my %Disallowed = ();

# first function called by a WeeChat-script.
weechat::register($prgname, "Nils Görs <weechatter\@arcor.de>", $version,
                  "GPL3", $description, "", "");

# commands used by jnotify. Type: /help jnotify
weechat::hook_command($prgname, $description,

	"<toggle> | <status> | <block> | <wl> | <wl> | <wl_add> / <wl_del> / <bl_add> / <bl_del> [nick_1 [... nick_n]]", 

	"<toggle>           $prgname between on and off\n".
	"<status>           tells you if $prgname is on or off\n".
	"<block>            toggle the 'block current channel' option on/off\n".
	"<wl>               shows entries in whitelist\n".
	"<bl>               shows entries in blacklist\n".
	"<wl_add> [nick(s)] add nick(s) to the whitelist\n".
	"<wl_del> [nick(s)] delete nick(s) from the whitelist\n".
	"<bl_add> [nick(s)] add nick(s) to the blacklist\n".
	"<bl_del> [nick(s)] delete nick(s) from the blacklist\n".
	"\n".
	"Options:\n".
	"'whitelist': path/file-name to store a list of nicks, channels and servers you would like to be inform if someone joins.\n".
	"'blacklist': path/file-name to store a list of nicks, channels and servers you would like to ignore.\n".
	"'cmd'      : command that should be executed if a user joins the same channel\n".
	"             '%N' will be replaced with users nick\n".
	"             '%C' will be replaced with name of channel\n".
	"             '%S' will be replaced with the internal server name (use '/server' to see the internal server names)\n".
	"'block_current_buffer': if 'on' blocks external command if user/buddy joins the current channel you are in. join in other channels will be displayed.\n".
	"\n".
	"Examples:\n".
	"Show entries in whitelist:\n".
	"/$prgname wl\n".
	"Add entries to blacklist (nick, server, channel):\n".
	"/$prgname bl_add nickname freenode #weechat\n".
	"Delete entries from whitelist (channel, nick, server):\n".
	"/$prgname wl_del #weechat nickname freenode\n".
	"Toggle option block_current_buffer (on|off):\n".
	"/$prgname block\n".
	"Set the variable for the external command (i recommend to use /iset script):\n".
	" /set plugins.var.perl.$prgname.cmd \"notify-send -t 9000 -i ~/.weechat/some_pic.png \"Channel: %C on Server: %S\" \"new User: %N\"\n",
	"toggle|status|block|wl|bl|wl_add|wl_del|bl_add|bl_del", "switch", "");

init();
weechat::hook_config( "plugins.var.perl.$prgname.$status", 'toggled_by_set', "" );

# create hook_signal for IRC command JOIN 
hook() if (weechat::config_get_plugin($status) eq "on");

# return 0 on error
sub hook
{
	$Hooks{notify_me} = weechat::hook_signal("*,irc_in_join", "notify_me", ""); # (servername, signal, script command, arguments)
	if ($Hooks{notify_me} eq '')
		{
			weechat::print("","ERROR: can't enable $prgname, hook failed ");
			return 0;
		}

	return 1;
}

sub unhook
{
	weechat::unhook($Hooks{notify_me}) if %Hooks;
	%Hooks = ();
}

sub notify_me
{
	my ($data, $buffer, $args) = ($_[0], $_[1], $_[2]);		# save callback from hook_signal

	my $mynick = weechat::info_get("irc_nick", split(/,/,$buffer));	# get current nick on a server
	my $newnick = weechat::info_get("irc_nick_from_host", $args);	# get nickname from new user
	my ($channelname) = ($args =~ m!.*:(.*)!);			# extract channel name from hook_signal
	my ($server_name) = split(/,/,$buffer);				# extract internal server name from hook_signal

	my $current_buffer = weechat::current_buffer;			# get current buffer
	$block_current_buffer = weechat::config_get_plugin("block_current_buffer");	# get user settings from block_current_buffer
	my $buffer_user_in = weechat::buffer_get_string($current_buffer, "short_name");# get short_name of buffer


	return weechat::WEECHAT_RC_OK if ($mynick eq $newnick);		# did i join the channel?

	# If user setting "block_current_buffer" is "on"
	if ($block_current_buffer eq "on"){
	return weechat::WEECHAT_RC_OK if ($buffer_user_in eq $channelname);
	}

	my $external_command = weechat::config_get_plugin('cmd');	# get external command (user settings)
	$external_command =~ s/%C/$channelname/;			# replace string '%C' with $channelname
	$external_command =~ s/%N/$newnick/;				# replace string '%N' with $newnick
	$external_command =~ s/%S/$server_name/;			# replace string '%S' with $server_name

	if ( exists $Allowed{$newnick} or exists $Allowed{$channelname} or exists $Allowed{$server_name}) {	# User or Channel or Buffer in Whitelist?
	system($external_command . "&");				# start external program
	return weechat::WEECHAT_RC_OK;
	}elsif((my $n = keys %Allowed) ne "0"){				# whitelist empty?
		  return weechat::WEECHAT_RC_OK;			# no.
		}

	if ( exists $Disallowed{$newnick} or exists $Disallowed{$channelname} or exists $Disallowed{$server_name}) {	# User or Channel in Blacklist?
	return weechat::WEECHAT_RC_OK;
	}


	system($external_command . "&");				# start external program if no white and blacklist exists.

	return weechat::WEECHAT_RC_OK;
}

sub toggled_by_set
{
	my $value = $_[2];

	if ($value ne 'on')
		{
			weechat::config_set_plugin($status, "off")	unless ($value eq 'off') ;
			if (defined $Hooks{notify_me}) {
				weechat::print('',"$prgname disabled value: $value");
				unhook();
			}
		}
	else
		{
			if (not defined $Hooks{notify_me}) {
				weechat::print("","$prgname enabled");
				weechat::config_set_plugin($status, "off")
					unless  hook();			# fall back to 'off' if hook(9 fails
			}
		}
	return weechat::WEECHAT_RC_OK;					# Return_Code OK
}

sub switch
{
	my ($getargs) = ($_[2]);
	my $jnotify = weechat::config_get_plugin($status);		# get value from jnotify
	my $block_current_stat = weechat::config_get_plugin("block_current_buffer");

	if ($getargs eq $status or "")
		{
			weechat::print("","Status of $prgname is         : $jnotify");	# print status of jnotify
			weechat::print("","blocking of current buffer is: $block_current_stat");
			return weechat::WEECHAT_RC_OK;			# Return_Code OK
		}

	if ($getargs eq "toggle"){
		if ($jnotify eq "on")
			{
				weechat::config_set_plugin($status, "off");
			}
		else
			{
				weechat::config_set_plugin($status, "on");
			}
		return weechat::WEECHAT_RC_OK;
		}

	if ($getargs eq "block"){
		if ($block_current_stat eq "on")
			{
				weechat::config_set_plugin("block_current_buffer", "off");
			}
		else
			{
				weechat::config_set_plugin("block_current_buffer", "on");
			}
		return weechat::WEECHAT_RC_OK;
		}

	if ($getargs eq "wl")
		{
		  whitelist_show();
		  return weechat::WEECHAT_RC_OK;
		}
	if ($getargs eq "bl")
		{
		  blacklist_show();
		  return weechat::WEECHAT_RC_OK;
		}
	 else
		{
		  my ( $cmd, $arg ) = ( $getargs =~ /(.*?)\s+(.*)/ );			# cut cmd from nicks
		  $cmd = $getargs unless $cmd;
# check cmd "whitelist add/del" and "blacklist add/del"
		    if ($cmd eq "wl_add")
		      {
			  _add("wl_add",$arg);
		      }
		    if ($cmd eq "wl_del")
		      {
			  _del("wl_del",$arg);
		      }
		    if ($cmd eq "bl_add")
		      {
			  _add("bl_add",$arg);
		      }
		    if ($cmd eq "bl_del")
		      {
			  _del("bl_del",$arg);
		      }

		}
}

# whitelist and blacklist reader and saver (routines from rettubs query_blocker)
sub whitelist_read {
    my $whitelist = weechat::config_get_plugin( "whitelist" );
    return unless -e $whitelist;
    open (WL, "<", $whitelist) || DEBUG("$whitelist: $!");
	while (<WL>) {
		chomp;
		$Allowed{$_} = 1  if length $_;
	}
	close WL;
}
sub whitelist_save {
    my $whitelist = weechat::config_get_plugin( "whitelist" );
    open (WL, ">", $whitelist) || DEBUG("write whitelist: $!");
    print WL "$_\n" foreach ( sort { "\L$a" cmp "\L$b" } keys %Allowed );
    close WL;
}
sub blacklist_read {
    my $blacklist = weechat::config_get_plugin( "blacklist" );
    return unless -e $blacklist;
    open (BL, "<", $blacklist) || DEBUG("$blacklist: $!");
	while (<BL>) {
		chomp;
		$Disallowed{$_} = 1  if length $_;
	}
	close BL;
}
sub blacklist_save {
    my $blacklist = weechat::config_get_plugin( "blacklist" );
    open (BL, ">", $blacklist) || DEBUG("write blacklist: $!");
    print BL "$_\n" foreach ( sort { "\L$a" cmp "\L$b" } keys %Disallowed );
    close BL;
}

# add and delete nicks from white and blacklist
sub _add {
    my ($cmd,$args) = ($_[0],$_[1]);

    if (defined $args) {
       foreach ( split( / +/, $args ) ) {
	if ($cmd eq "wl_add")
	  {
	      $Allowed{$_} = 1;
	      whitelist_save();
	  }
	elsif ($cmd eq "bl_add")
	  {
	      $Disallowed{$_} = 1;
	      blacklist_save();
	  }
       }
    }
    else{
        weechat::print("", "$prgname : There is no nick to be added.");
    }
}
sub _del {
    my ($cmd,$args) = ($_[0],$_[1]);
    if (defined $args) {
       foreach ( split( / +/, $args ) ) {
	  if ($cmd eq "wl_del" and exists $Allowed{$_})
	  {
	      $Allowed{$_} = 1;
	      delete $Allowed{$_};
	      weechat::print("", "$prgname: Nick ". get_color($_) . $_ . weechat::color("reset") . " removed from whitelist.");
	      whitelist_save();
	  }elsif ($cmd eq "wl_del") {
	      weechat::print("", "$prgname: Nick " . get_color($_) .  $_ . weechat::color("reset") . " not in whitelist. Nothing removed.");
	  }

	  if ($cmd eq "bl_del" and exists $Disallowed{$_})
	  {
	      $Disallowed{$_} = 1;
	      delete $Disallowed{$_};
	      weechat::print("", "$prgname: Nick ". get_color($_) . $_ . weechat::color("reset") . " removed from blacklist.");
	      blacklist_save();
	  }elsif ($cmd eq "bl_del") {
	      weechat::print("", "$prgname: Nick " . get_color($_) .  $_ . weechat::color("reset") . " not in blacklist. Nothing removed.");
	  }
       }
    }
    else{
        weechat::print("", "$prgname : There is no nick to be removed.");
    }
}

# get color routine by rettub
sub get_color {
    my $color = 0;
    foreach my $c (split(//, $_[0]))
    {
        $color += ord($c);
    }
    $color = ($color %
             weechat::config_integer (weechat::config_get ("weechat.look.color_nicks_number")));

    my $color_name = sprintf("chat_nick_color%02d", $color + 1);
    
    return weechat::color ($color_name);
}


sub whitelist_show{
    weechat::print("", "$prgname: whitelist" );
    if ((my $n = keys %Allowed) eq "0" ){
      weechat::print("","     list is empty");
    return;
    }

    foreach ( sort { "\L$a" cmp "\L$b" } keys %Allowed ) {
	  weechat::print("","     " . $_);
    }
}
sub blacklist_show{
    weechat::print("", "$prgname: blacklist" );
    if ((my $n = keys %Disallowed) eq "0" ){
      weechat::print("","     list is empty");
    return;
    }

    foreach ( sort { "\L$a" cmp "\L$b" } keys %Disallowed ) {
	  weechat::print("","     " . $_);
    }
}

sub init{
# set value of script (for example starting script the first time)
weechat::config_set_plugin("cmd", $extern_command)
	if (weechat::config_get_plugin("cmd") eq "");

weechat::config_set_plugin($status, $default_status)
	if (weechat::config_get_plugin($status) eq "");

    if ( weechat::config_get_plugin($whitelist) eq '' ) {
        my $wd = weechat::info_get( "weechat_dir", "" );
        $wd =~ s/\/$//;
        weechat::config_set_plugin($whitelist, $wd . "/" . $default_whitelist );
    }
    if ( weechat::config_get_plugin($blacklist) eq '' ) {
        my $wd = weechat::info_get( "weechat_dir", "" );
        $wd =~ s/\/$//;
        weechat::config_set_plugin($blacklist, $wd . "/" . $default_blacklist );
    }

weechat::config_set_plugin("block_current_buffer", $block_current_buffer)
	if (weechat::config_get_plugin("block_current_buffer") eq "");

whitelist_read();
blacklist_read();
}
sub DEBUG {weechat::print('', "***\t" . $_[0]);}