#!/usr/bin/env python3
"""Run the stub-environment tests with a Lua 5.1 runtime (pip install lupa)."""
import os
import sys

try:
    from lupa.lua51 import LuaRuntime
except ImportError:  # pragma: no cover
    from lupa import LuaRuntime

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = LuaRuntime(unpack_returned_tuples=True)
runner = lua.eval("function(root) local chunk = assert(loadfile(root .. '/tests/run_tests.lua')) return chunk(root) end")
try:
    runner(root)
except Exception as exc:  # lupa raises for os.exit(1) and for Lua errors
    message = str(exc)
    if "exit" not in message:
        print("ERROR:", message)
    sys.exit(1)
