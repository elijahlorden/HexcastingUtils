local protocol = require("HexUtils/CompilerProtocol")

parallel.waitForAll(function() protocol.host({ "/HexLibs", "/HexPrograms" }) end, function() shell.run("shell") end)
