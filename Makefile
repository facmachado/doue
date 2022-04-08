#
#  Makefile for doue
#
#  Copyright (c) 2021 Flavio Augusto (@facmachado)
#
#  This software may be modified and distributed under the terms
#  of the MIT license. See the LICENSE file for details.
#


#
# Initial consts & vars
#

.RECIPEPREFIX=.
.DEFAULT_GOAL=$(shell uname -m)

CC=gcc
CFLAGS=-O2 -mmusl --static -Wl,--build-id=none,--strip-all,--discard-all

PREFIX=/usr/local


#
# Pattern workarounds for batch compiling
#

apps:
. $(CC) $(CFLAGS) doued.c -o doued
. CC=$(CC) CFLAGS="$(CFLAGS)" shc -rUf doue.sh -o doue
. chmod 700 doued doue


#
# Arch directives
#

# x86_64: $(BIN)
x86_64: apps


#
# Setup.exe routines
#

# install:
# ifeq ($(.DEFAULT_GOAL), x86_64)
# . (for i in $(BIN); do cp $$i $(PREFIX)/bin; chmod 700 $(PREFIX)/bin/$$i; done)
# endif

# uninstall:
# . (cd $(PREFIX)/bin && rm -f $(BIN))


#
# Project routines
#

test:
. make && ./doued

clean:
. rm -f doued doue doue.sh.x.c
