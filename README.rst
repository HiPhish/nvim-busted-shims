.. SPDX-FileCopyrightText: © 2024 Alejandro "HiPhish" Sanchez
.. SPDX-License-Identifier: CC0-1.0

.. default-role:: code

#########################
 Busted shims for Neovim
#########################

Minimal command-line adapters to facilitate writing Neovim plugins tests using
the busted Lua test framework.

.. contents::
   :depth: 2


What and why
############

This repository is a collection of command-line interface adapters (shims) for
running Neovim_ tests using the busted_ test framework.  To run any tests which
call Neovim's Lua API (which is pretty much any non-trivial test) we need to
tell busted to use Neovim as our Lua interpreter.  Additionally we want to
isolate the Neovim process from our own Neovim configuration.

These shims take care of all of this.  This is the mandatory boilerplate code
you would otherwise have to copy and paste into every of your plugins.

Currently the shims will only work on Unix systems.  I don't use or know the
Windows command line, so contributions are welcome.


Guiding principles
==================

Minimal
   Minimal code means minimal maintenance and minimal bugs.  All the shims use
   what we already have and do not have any complex logic.

Self-contained
   Contributors should not have to install any plugins into their own Neovim
   configuration.  These shims contain everything that's needed, except for
   Neovim and busted themselves of course.

Minimally opinionated
   The shims are just thin wrappers, they do not impose onto you how to write
   your tests.

Familiar configuration
   Configuring the shims is no different from configuring Neovim, there is no
   custom API or new DSL to learn.  You can freely choose between Lua and Vim
   script.


Usage
#####

TL;DR: Add this repository as a submodule and use the shims instead of their
real counterparts.  Here is an example:

.. code:: sh

   # Use what ever target directory you want instead of `test/bin`
   git submodule add https://gitlab.com/HiPhish/nvim-busted-shims.git test/bin
   # Set the Lua shim as your Lua interpreter
   echo 'return {_all = {lua = "./test/bin/lua"}}' > .busted
   # Run tests
   ./test/bin/busted
   # Use the interactive isolated Neovim
   ./test/bin/nvim

The isolated Neovim will use `test/xdg` for its standard directories (e.g.
`test/xdg/config` for configuration).  See `:h xdg` for the full list of
standard directories.  This common base path cannot be changed at the moment,
patches are welcome.

.. warning::

   Do not add this directory to your `PATH`.  The shims rely on the `PATH` to
   find the actual executables.

Adding your plugin to the isolated Neovim
=========================================

The isolated Neovim does not have access to your own configuration, so most
likely it does not have access to the plugin it is trying to test.  We can
solve this problem by adding the path of the plugin to the isolated Neovim's
runtime path (see `:h 'runtimepath'`).

Add the following to `test/xdg/config/nvim/init.vim`:

.. code:: vim

   execute 'set rtp+=' .. getcwd()

If you prefer Lua add this to `test/xdg/config/nvim/init.lua` instead:

.. code:: lua

   vim.opt.runtimepath:append(vim.fn.getcwd())


Tutorial: Our first test
########################

Let's write a simple test for a toy plugin.  Our plugin will provide a command
which sets a variable to a random number.  Pretty useless, but simple enough to
demonstrate how to write tests with these shims.  First we create a new
directory with a plugin file.

.. code:: sh

   mkdir set-secret-var.nvim
   cd set-secret-var.nvim
   mkdir plugin
   touch plugin/set-secret-var.vim

The plugin file is very simple as well:

.. code:: vim

   " File: plugin/set-secret-var.vim
   command! SetSecretVar let g:secret = rand()

This plugin is written in Vim script, so we cannot run it directly in a Lua
interpreter.  Furthermore, it only acts through side effects, so it can only be
used from within Neovim.  Now we need to add the shims:

.. code:: sh

   git submodule add https://gitlab.com/HiPhish/nvim-busted-shims.git test/bin

I have chosen `test/bin` for the shims, but any directory will work.  Busted
encourages putting your tests next to your Lua modules, but there are no Lua
modules here.  Even if this plugin file was written in Lua, it would not be a
Lua module because it is not meant to be required by other modules.  I will
therefore put my test in a separate directory.

.. code:: sh

   mkdir -p test/spec
   touch test/spec/secret.lua
   touch .busted

First we need to instruct busted to use our shims and to find our tests.  Add
this to your `.busted` file:

.. code:: lua

   -- File: .busted
   return {
	   _all = {
		   lua = './test/bin/lua',
		   ROOT = {'./test/spec/'},
		   pattern = '',
	   }
   }

At this point we can take busted for a spin.

.. code:: lua

   ./test/bin/busted

Of course busted will not find any tests because we have not yet defined
anything.  Let's add a trivial test.

.. code:: lua

   -- File: test/spec/secret.lua
   it('always succeeds', function()
       assert.is_true(true)
   end)

You should get one passing test.  Let's go ahead and define a proper test now.

.. code:: lua

   describe('The secret', function()
       local nvim

       before_each(function()
           local command = {'nvim', '--embed', '--headless'}
           local jobopts = {rpc = true}
           nvim = vim.fn.jobstart(command, jobopts)
       end)

       after_each(function()
           vim.rpcnotify(nvim, 'nvim_command', 'quitall!')
           vim.fn.jobwait({nvim})
       end)

       it('is set', function()
           vim.rpcrequest(nvim, 'nvim_command', 'SetSecretVar')
           local secret = vim.rpcrequest(nvim, 'nvim_get_var', 'secret')
           assert.is_number(secret)
       end)
   end)

In case you are wondering why we can just write `nvim` in our test instead of
having to reference the shim: the shim exports the XDG environment variables,
so any descendant Neovim process will also run in the isolated environment.  It
just works.

If you run this test you will get an error.  The shim cannot find our new
command because the plugin is not part of the isolated environment.  Let's add
it.  The configuration directory of the isolated environment is
`test/xdg/config/nvim` and it works the same way as the original configuration
directory.  Create the config file `test/xdg/config/nvim/init.vim` with the
following content:

.. code:: vim

   " File: test/xdg/config/nvim/init.vim
   execute 'set rtp+=' .. getcwd()

Now the test will pass.  But just look at how much of a mouthful it is to get
an embedded Neovim running.  I use the plugin yo-dawg.nvim_ to get rid of all
this boilerplate code.  You do not have to use it, anything else that cuts own
on the boilerplate will work just as well.  This is simply what I use.  Let's
add yo-dawg as a submodule.

.. code:: sh

   git submodule add \
       https://gitlab.com/HiPhish/yo-dawg.nvim.git \
       test/xdg/local/share/nvim/site/pack/testing/start/yo-dawg.nvim

Note that I cloned to submodule into a Neovim standard directory for plugins
(see `:h packages`).  That way Neovim can find it without needing any plugin
manager.  Now we can update our test.

.. code:: lua

   -- File: test/spec/secret.lua
   local yd = require 'yo-dawg'

   describe('The scret', function()
       local nvim
       before_each(function() nvim = yd.start() end)
       after_each(function() yd.stop(nvim) end)

       it('is set', function()
           nvim:command 'SetSecretVar'
           local secret = nvim:get_var('secret')
           assert.is_number(secret)
       end)
   end)

With this we have reached the end of the tutorial.  To recapitulate, we have
performed the following steps:

- Add shims as as submodule to the plugin
- Add test configuration for the shims to find the plugin
- Set up busted to use the shims and find our tests
- Write the tests
- Run the tests through the busted shim


The shims
#########

There are three shims:

- `busted` calls Luarocks to temporarily set up the `PATH` to find the real
  busted executable
- `lua` is the most complex shim, it invokes Neovim set up to act as a Lua
  interpreter
- `nvim` invokes Neovim isolated from your personal configuration


busted
======

This is the main shim, it depends on Luarocks and busted.  The `luarocks`
executable must be in your `PATH`.  It calls Luarocks to adjust the `PATH` to
include Lua 5.1 executables, then passes all its arguments to the real busted
command.

This shim is mostly meant for automated tooling which can only take a path to
one executable file, such as neotest-busted_.

lua
===

If your test depends on Neovim's Lua API you have to instruct busted to use
Neovim as your Lua interpreter.  Neovim has the `-l` flag (see `:h -l`) which
makes Neovim act as an interpreter for Lua scripts.  However, busted expects
the interpreter to have the same command-line interface as the standalone Lua
interpreter.  This shim acts as an adapter that translates between the two
interfaces.

Busted will not pick up the Lua shim on its own, you have to instruct it which
Lua executable to use.  You can add something like this to your `.busted` file:

.. code:: lua

   return {
	   _all = {
		   lua = './test/bin/lua',
	   },
   }


nvim
====

This shim exists for convenience only.  If you want to manually try out your
plugin in the isolated Neovim you can call this shim.  All it does is set up
the XDG environment variables and then pass on all command-line arguments to
Neovim.



Recipes
#######

The following section contains my personal collections of tricks of the trade.
If you have any of your to add you are welcome to contribute.


Configure the isolated Neovim
=============================

If you need some initial configuration for your plugin in the isolated
environment you can add it to `test/xdg/config/nvim` like any other
configuration.

Managing dependencies
=====================

If your plugin depends on some other plugin you will need to add that other
plugin to the isolated environment.  I like to use Git submodules for that.
Let's say your plugin depends on nvim-treesitter_, then you would add it like
this:

.. code:: sh

   git submodule add https://github.com/nvim-treesitter/nvim-treesitter \
      test/xdg/local/share/nvim/site/pack/testing/start/nvim-treesitter

See `:h packages` for more information on how to manually add packages.  If you
want to updated the dependency you can execute this command:

.. code:: sh

   git submodule update --remote \
      test/xdg/local/share/nvim/site/pack/testing/start/nvim-treesitter

See `git-submodule(1)` for information on Git submodules.

Embedded Neovim inside tests
============================

For some complex tests you might have to run an embedded Neovim process from
within your test and remotely control it through the RPC API (see `:h api`).
You could start the process yourself and send the messages, but there will be a
lot of boilerplate code.  I recommend the plugin `yo-dawg.nvim`_ for this.

.. code:: lua

   local yd = require 'yo-dawg'

   describe('File type tests', function()
       local nvim

       before_each(function()
           nvim = yd.start()
       end)

       after_each(function()
           yd.stop(nvim)
       end)

       it('recognizes the file type', function()
           nvim:command('edit some_file.vim')
           local ft = nvim:get_option_value('filetype', {})
           assert.are.equal('vim', ft)
       end)
   end)

Before each test we use `yd.start` to create an embedded Neovim process and we
bind it to the variable `nvim`.  After each test we clean up by stopping the
embedded process.  During each test we can call the Neovim API through methods
on the `nvim` object.  There is a 1:1 correspondence between an API function
and a method: the name of the method is the name of the function minus the
`nvim_` prefix.

For more information pleas refer to the yo-dawg.nvim documentation.

Add your own assertions
=======================

You can add your own busted configurations by adding them to the isolated
Neovim configuration.  The `init.lua` file is a good place, but personally I
prefer a separate file like `plugin/busted.lua`.

.. code:: lua

   -- Custom configuration for busted

   -- If busted is not available this configuration is not running as part of a
   -- test, so there is nothing to do.
   local success, say = pcall(require, 'say')
   if not success then
       return
   end
   local assert = require 'luassert'

   -- This table is only used as a unique identifier
   local NVIM_STATE_KEY = {}

   ---Add the Neovim client to the current test state.
   local function nvim_client(state, args, _level)
       assert(args.n > 0, "No Neovim channel provided to the modifier")
       assert(rawget(state, NVIM_STATE_KEY) == nil, "Neovim client already set")
       rawset(state, NVIM_STATE_KEY, args[1])
       return state
   end

   ---Assert that the current buffer has the expected file type
   local function has_filetype(state, args, _level)
       local nvim = rawget(state, NVIM_STATE_KEY)
       local filetype = args[1]

       return filetype == nvim:get_option_value('filetype', {})
   end

   -- Register custom messages
   say:set('assertion.has_filetype.positive', 'Expected file type %s')
   say:set('assertion.has_filetype.negative', 'File type should have been %s')

   -- Register custom modifier
   assert:register('modifier', 'nvim', nvim_client)

   -- Register custom assertion
   assert:register(
       'assertion', 'has_filetype', has_filetype,
       'assertion.has_filetype.positive', 'assertion.has_filetype.negative'
   )

This script has a guard at the beginning which will abort execution of the
script if the libraries from busted are not available.  This lets you use the
`nvim` shim interactively without the busted code throwing errors.

With the custom modifier and assertion we can write assertions which are much
more concise and readable.

.. code:: lua

    it('recognizes the file type', function()
        nvim:command('edit some_file.vim')
        assert.nvim(nvim).has_filetype('vim')
    end)

Refer to the busted documentation for details on how to write custom modifiers
and assertions.


Further reading
###############

Articles and blog posts
=======================

- `Testing Neovim plugins with Busted <https://hiphish.github.io/blog/2024/01/29/testing-neovim-plugins-with-busted/>`__
- `Using Neovim as Lua interpreter with Luarocks <https://zignar.net/2023/01/21/using-luarocks-as-lua-interpreter-with-luarocks/>`__

Similar projects
================

nlua_
   Another command-line interpreter adapter, but written in Lua instead.

neotest-busted_
   Busted adapter for the neotest_ plugin.
   
plenary.nvim_
   Contains among other things its own implementation of busted.  Since this is
   not the real busted it does not require any shims.

mini.test_
   Test framework specific to Neovim.


License
#######

All source code is released under the terms of the Unlicense, the documentation
is under the CC0-1.0 license.  See the files in the LICENSE_ directory for
details.  I don't know if something this simple even needs a license, but here
you have one just in case.


.. _Neovim: https://neovim.io/
.. _busted: https://lunarmodules.github.io/busted/
.. _neotest-busted: https://gitlab.com/HiPhish/neotest-busted
.. _nvim-treesitter: https://github.com/nvim-treesitter/nvim-treesitter
.. _yo-dawg.nvim: https://gitlab.com/HiPhish/yo-dawg.nvim
.. _nlua: https://github.com/mfussenegger/nlua
.. _neotest: https://github.com/nvim-neotest/neotest
.. _plenary.nvim: https://github.com/nvim-lua/plenary.nvim
.. _mini.test: https://github.com/echasnovski/mini.test
.. _LICENSE: LICENSE.txt
