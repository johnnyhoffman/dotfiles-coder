-- Run headless by install.sh after `Lazy! restore`: pre-install every mason
-- package the config would otherwise fetch lazily on first use — tools from
-- mason.nvim's ensure_installed, plus LSP servers from the lspconfig
-- `servers` opts (those only install when a matching file opens, so a plain
-- headless run never gets them). :MasonInstall blocks in headless mode,
-- which is what makes this synchronous.
--
-- Discovery is pcall-armored end to end: on any internal-API drift this
-- warns and exits cleanly, and packages simply install lazily like before.

local function warn(msg)
    io.stderr:write("[nvim-provision] " .. msg .. "\n")
end

if not pcall(vim.cmd, "Lazy! load all") then
    warn("could not load plugins; skipping mason pre-install")
    return
end

local ok_cfg, Config = pcall(require, "lazy.core.config")
local ok_plg, Plugin = pcall(require, "lazy.core.plugin")
if not (ok_cfg and ok_plg) then
    warn("lazy internals unavailable; skipping")
    return
end

local function opts_of(name)
    local p = Config.spec.plugins[name]
    if not p then
        return {}
    end
    local ok, o = pcall(Plugin.values, p, "opts", false)
    return (ok and type(o) == "table") and o or {}
end

local wanted = {}
for _, t in ipairs(opts_of("mason.nvim").ensure_installed or {}) do
    table.insert(wanted, t)
end

-- lspconfig server names → mason package names (the mapping module moved
-- across mason-lspconfig versions; try both homes).
local map = {}
local ok_v1, v1 = pcall(require, "mason-lspconfig.mappings.server")
if ok_v1 and v1.lspconfig_to_package then
    map = v1.lspconfig_to_package
else
    local ok_v2, v2 = pcall(function()
        return require("mason-lspconfig").get_mappings().lspconfig_to_package
    end)
    if ok_v2 and type(v2) == "table" then
        map = v2
    end
end
for server, sopts in pairs(opts_of("nvim-lspconfig").servers or {}) do
    local skip = type(sopts) == "table" and (sopts.mason == false or sopts.enabled == false)
    if not skip and map[server] then
        table.insert(wanted, map[server])
    end
end

if #wanted == 0 then
    warn("nothing discovered to install")
    return
end

local ok_reg, mr = pcall(require, "mason-registry")
if not ok_reg then
    warn("mason-registry unavailable; skipping")
    return
end
pcall(mr.refresh)

local seen, to_install = {}, {}
for _, name in ipairs(wanted) do
    local base = name:gsub("@.*", "") -- ensure_installed entries may pin "tool@version"
    if not seen[base] then
        seen[base] = true
        local okp, pkg = pcall(mr.get_package, base)
        if okp and not pkg:is_installed() then
            table.insert(to_install, name)
        elseif not okp then
            warn("unknown mason package: " .. base)
        end
    end
end

if #to_install == 0 then
    print("[nvim-provision] all mason packages already installed")
    return
end

print("[nvim-provision] installing: " .. table.concat(to_install, " "))
-- blocking in headless mode; raises if any package fails — the rest still
-- install, and failed ones retry lazily on first use, so just report it
local ok_install, err = pcall(vim.cmd, "MasonInstall " .. table.concat(to_install, " "))
if not ok_install then
    warn("some packages failed (they will retry lazily on first use): " .. tostring(err))
end
