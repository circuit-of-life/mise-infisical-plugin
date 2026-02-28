local cmd = require("cmd")
local json = require("json")

function PLUGIN:MiseEnv(ctx)
    local infisical = ctx.options.infisical_bin or "infisical"
    local environment = ctx.options.environment
    local path = ctx.options.path
    local project_id = ctx.options.project_id

    local command = infisical .. " secrets --output json"
    if environment then
        command = command .. " --env " .. environment
    end
    if path then
        command = command .. " --path " .. path
    end
    if project_id then
        command = command .. " --projectId " .. project_id
    end

    local ok, output = pcall(function()
        return cmd.exec(command)
    end)

    if not ok then
        print("[mise-infisical] warning: `" .. command .. "` failed: " .. tostring(output))
        return {env = {}}
    end

    local decode_ok, secrets = pcall(json.decode, output)
    if not decode_ok then
        print("[mise-infisical] warning: failed to parse JSON from `" .. command .. "`: " .. tostring(data))
        return {env = {}}
    end

    if not secrets then
        return
    end

    local env_vars = {}
    for _, item in ipairs(secrets) do
        local key = item.secretKey
        local value = item.secretValue

        table.insert(env_vars, {key = key, value = value})
    end

    return {
        env = env_vars,
        redact = true
    }
end