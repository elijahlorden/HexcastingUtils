local Compiler = require("HexUtils/Compiler")

local compiler = Compiler.new()
compiler:compile("test.xth", { "/" })
compiler:emit(Compiler.EmitMode.DuckyDumpToFile, "/test.dump")
compiler:emit(Compiler.EmitMode.DuckyFocalPort, peripheral.find("focal_port"))
