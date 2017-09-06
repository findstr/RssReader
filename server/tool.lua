local gmatch = string.gmatch
local M = {}

function M.jsondecode(src, out)
	for k, v in gmatch(src, '"([^"]+)":"([^"]+)"') do
		out[k] = v
	end
end

return M

