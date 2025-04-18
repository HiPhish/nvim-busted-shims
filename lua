#!/bin/sh
# SPDX-FileCopyrightText: © 2024 Alejandro "HiPhish" Sanchez
# SPDX-License-Identifier: Unlicense

# This is free and unencumbered software released into the public domain.
#
# Anyone is free to copy, modify, publish, use, compile, sell, or distribute
# this software, either in source code form or as a compiled binary, for any
# purpose, commercial or non-commercial, and by any means.
#
# In jurisdictions that recognize copyright laws, the author or authors of
# this software dedicate any and all copyright interest in the software to
# the public domain.  We make this dedication for the benefit of the public
# at large and to the detriment of our heirs and successors.  We intend this
# dedication to be an overt act of relinquishment in perpetuity of all
# present and future rights to this software under copyright law.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
# AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# For more information, please refer to <https://unlicense.org/>


# A shim which acts as a command-line interface adapter to use Neovim as a Lua
# interpreter.

# Set custom XDG base directory paths to isolate the test Neovim from the
# user's own configuration and data files.
export XDG_CONFIG_HOME='test/xdg/config/'
export XDG_STATE_HOME='test/xdg/local/state/'
export XDG_DATA_HOME='test/xdg/local/share/'

# Handle Lua command-line arguments; not all options are supported
while getopts 'ilEve:' opt; do
	case $opt in
		e) lua_expr=$OPTARG;;
		v) nvim --version; exit;;
		i | l | E) echo "Option '$opt' not supported by shim"; exit 1;;
	esac
done


if [ -n "$lua_expr" ]; then
	nvim --headless -c "lua $lua_expr" -c 'quitall!'
else
	# We have to explicitly enable plugins and user configuration, see ':h -l'
	if [ -r ${XDG_CONFIG_HOME}/nvim/init.lua ]; then
		nvim --cmd 'set loadplugins' -u "${XDG_CONFIG_HOME}/nvim/init.lua" -l $@
	elif [ -r ${XDG_CONFIG_HOME}/nvim/init.vim ]; then
		nvim --cmd 'set loadplugins' -u "${XDG_CONFIG_HOME}/nvim/init.vim" -l $@
	else
		nvim --cmd 'set loadplugins' -l $@
	fi

fi

exit_code=$?

exit $exit_code
