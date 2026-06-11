local cmd = require("cmd")
local log = require("log")
local json = require("json")

function PLUGIN:MiseEnv(ctx)
    local infisical = ctx.options.infisical_bin or "infisical"
    local environment = ctx.options.environment
    local folder = ctx.options.folder
    local project_id = ctx.options.project_id
    local domain = ctx.options.domain

    local command = infisical .. " export --format json"

    if environment then
        command = command .. " --env " .. environment
    end

    if folder then
        command = command .. " --path " .. folder
    end

    if project_id then
        command = command .. " --projectId " .. project_id
    end

    if domain then
        command = command .. " --domain " .. domain
    end

    log.info("fetching secrets")

    local exec_env = {}
    local token = os.getenv("INFISICAL_TOKEN")
    local is_ci = os.getenv("CI") == "true"

    if not token or token == "" then
        if is_ci then
            log.warn("INFISICAL_TOKEN not set, skipping secret fetch")
            return {cacheable = false, watch_files = {}, env = {}, redact = true}
        end
    end

    if token and token ~= "" then
        exec_env["INFISICAL_TOKEN"] = token
    end

    if domain and domain ~= "" then
        exec_env["INFISICAL_DOMAIN"] = domain
    end

    local ok, output = pcall(function()
        return cmd.exec(command, {env = exec_env})
    end)

    if not ok then
        log.error("infisical failed:", output)
        return {cacheable = false, watch_files = {}, env = {}, redact = true}
    end

    local decode_ok, data = pcall(json.decode, output)
    if not decode_ok then
        log.error("failed to parse JSON from infisical:", data)
        return {cacheable = false, watch_files = {}, env = {}, redact = true}
    end

    local env_vars = {}
    for _, secret in ipairs(data) do
        table.insert(env_vars, {key = secret.key, value = secret.value})
    end

    return {
        env = env_vars,
        redact = true,
        cacheable = true,
        watch_files = {}
    }
end