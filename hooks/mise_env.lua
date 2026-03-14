local cmd = require("cmd")
local file = require("file")
local log = require("log")

local function now()
    return os.time()
end

local function is_windows()
    return package.config:sub(1,1) == "\\"
end

local function read_number(path)
    if not file.exists(path) then
        return nil
    end

    local content = file.read(path)
    if not content then
        return nil
    end

    return tonumber(content)
end

local function write_number(path, value)
    local f = io.open(path, "w")

    if not f then
        return
    end

    f:write(tostring(value))
    f:close()
end

local function ensure_dir(path)
    if file.exists(path) then
        return
    end

    if is_windows() then
        os.execute('mkdir "' .. path .. '" >nul 2>&1')
    else
        os.execute('mkdir -p "' .. path .. '" >/dev/null 2>&1')
    end
end

function PLUGIN:MiseEnv(ctx)
    local infisical = ctx.options.infisical_bin or "infisical"
    local environment = ctx.options.environment
    local folder = ctx.options.folder
    local format = ctx.options.format or "dotenv"
    local project_id = ctx.options.project_id
    local env_file = ctx.options.env_file or ".env.local"

    local token = ""

    if os.getenv("CI") then
        log.info("CI detected, using token")
        
        token = os.getenv("INFISICAL_TOKEN")

        if not token then
            log.warn("missing INFISICAL_TOKEN")
            return {
                env = {},
                redact = true,
            }
        end

        token = "INFISICAL_TOKEN=" .. token
    end

    local ttl = tonumber(ctx.options.cache_ttl) or 3600 -- (1h) seconds

    -- cache dir
    local cache_dir = file.join_path(".cache", "mise-infisical")
    local cache_file = file.join_path(cache_dir, "expires.txt")

    ensure_dir(cache_dir)

    local expires = read_number(cache_file)

    if expires and now() < expires and file.exists(env_file) then
        log.info("using cached secrets")
        return {
            env = {},
            redact = true,
        }
    end

    log.info("fetching secrets")

    local command = token .. " " .. infisical .. " export --output-file " .. env_file

    if environment then
        command = command .. " --env " .. environment
    end

    if folder then
        command = command .. " --path " .. folder
    end

    if format then
        command = command .. " --format " .. format
    end

    if project_id then
        command = command .. " --projectId " .. project_id
    end

    log.info("running:", command)

    local ok, output = pcall(function()
        return cmd.exec(command)
    end)

    if not ok then
        log.error("infisical failed:", output)
        return { env = {}, redact = true }
    end

    local new_expire = now() + ttl

    write_number(cache_file, new_expire)

    log.info("cache updated, expires in", ttl .. "s" )

    return {
        env = {},
        redact = true,
    }
end